import Foundation

public struct JSONNode: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case object, array, string, number, bool, null

        public var isContainer: Bool { self == .object || self == .array }
    }

    public enum PathComponent: Equatable, Sendable {
        case key(String)
        case index(Int)
    }

    public var id: String
    public var key: String
    public var kind: Kind
    public var depth: Int
    public var scalar: String?
    public var childCount: Int
    public var subtreeEnd: Int
    public var components: [PathComponent]

    public var displayValue: String {
        guard let scalar else { return "" }
        if scalar.count <= 300 { return scalar }
        return String(scalar.prefix(300)) + "…"
    }

    public var openBracket: String { kind == .array ? "[" : "{" }
    public var closeBracket: String { kind == .array ? "]" : "}" }
}

/// Tanani JSON daraxti sifatida ko'rsatish uchun DFS tartibidagi tugunlar.
/// `subtreeEnd` yig'ilgan tugunning avlodlarini bir sakrashda tashlab o'tishga
/// imkon beradi — yig'ish/yoyish katta tanada ham chiziqli.
public struct JSONTree: @unchecked Sendable {
    public static let nodeLimit = 40_000
    public static let defaultExpandedDepth = 2

    public let nodes: [JSONNode]
    public let identity: String
    /// Bo'sh bo'lmagan konteynerlar — «hammasini yig'ish» va toolbar holati uchun bir marta hisoblanadi.
    public let containerIDs: Set<String>
    private let root: Any

    public var count: Int { nodes.count }

    public init?(text: String, identity: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
              JSONTree.fitsNodeLimit(trimmed),
              let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: []),
              (obj is [String: Any]) || (obj is [Any]) else { return nil }
        var out: [JSONNode] = []
        out.reserveCapacity(256)
        guard JSONTree.walk(obj, key: "$", depth: 0, components: [], into: &out) else { return nil }
        nodes = out
        root = obj
        containerIDs = Set(out.filter { $0.kind.isContainer && $0.childCount > 0 }.map(\.id))
        self.identity = identity
    }

    static func fitsNodeLimit(_ text: String, limit: Int = JSONTree.nodeLimit) -> Bool {
        var nodes = 0
        var inString = false
        var escaped = false
        for byte in text.utf8 {
            if escaped { escaped = false; continue }
            if inString {
                if byte == 0x5C { escaped = true } else if byte == 0x22 { inString = false }
                continue
            }
            switch byte {
            case 0x22: inString = true
            case 0x2C, 0x7B, 0x5B: nodes += 1
            default: break
            }
            if nodes > limit { return false }
        }
        return true
    }

    private static func walk(_ value: Any, key: String, depth: Int, components: [JSONNode.PathComponent], into out: inout [JSONNode]) -> Bool {
        guard out.count < nodeLimit else { return false }
        let id = path(components)
        let index = out.count
        if let dict = value as? [String: Any] {
            out.append(JSONNode(id: id, key: key, kind: .object, depth: depth, scalar: nil, childCount: dict.count, subtreeEnd: index + 1, components: components))
            for k in dict.keys.sorted() {
                guard walk(dict[k] as Any, key: k, depth: depth + 1, components: components + [.key(k)], into: &out) else { return false }
            }
            out[index].subtreeEnd = out.count
            return true
        }
        if let arr = value as? [Any] {
            out.append(JSONNode(id: id, key: key, kind: .array, depth: depth, scalar: nil, childCount: arr.count, subtreeEnd: index + 1, components: components))
            for (i, item) in arr.enumerated() {
                guard walk(item, key: "[\(i)]", depth: depth + 1, components: components + [.index(i)], into: &out) else { return false }
            }
            out[index].subtreeEnd = out.count
            return true
        }
        let (kind, scalar) = scalarText(value)
        out.append(JSONNode(id: id, key: key, kind: kind, depth: depth, scalar: scalar, childCount: 0, subtreeEnd: index + 1, components: components))
        return true
    }

    static func scalarText(_ value: Any) -> (JSONNode.Kind, String) {
        if value is NSNull { return (.null, "null") }
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return (.bool, n.boolValue ? "true" : "false") }
            return (.number, numberText(n))
        }
        if let s = value as? String { return (.string, quoted(s)) }
        return (.string, quoted(String(describing: value)))
    }

    private static func numberText(_ n: NSNumber) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [n], options: [.fragmentsAllowed]),
           var text = String(data: data, encoding: .utf8) {
            text = text.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            if !text.isEmpty { return text }
        }
        return n.stringValue
    }

    private static func quoted(_ s: String) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: [s], options: [.fragmentsAllowed, .withoutEscapingSlashes]),
           let text = String(data: data, encoding: .utf8), text.count >= 2 {
            return String(text.dropFirst().dropLast())
        }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// JSONPath uslubi: `$.data.items[0].id`; identifikator bo'lmagan kalit `["..."]`.
    public static func path(_ components: [JSONNode.PathComponent]) -> String {
        var out = "$"
        for c in components {
            switch c {
            case .index(let i): out += "[\(i)]"
            case .key(let k):
                if isIdentifier(k) {
                    out += ".\(k)"
                } else {
                    out += "[\"" + k.replacingOccurrences(of: "\"", with: "\\\"") + "\"]"
                }
            }
        }
        return out
    }

    private static func isIdentifier(_ s: String) -> Bool {
        guard let first = s.first, first.isLetter || first == "_" else { return false }
        return s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    /// Yig'ilgan konteynerlarning avlodlari tashlab o'tiladi.
    public func rows(collapsed: Set<String>) -> [JSONNode] {
        var out: [JSONNode] = []
        out.reserveCapacity(min(nodes.count, 4096))
        var i = 0
        while i < nodes.count {
            let node = nodes[i]
            out.append(node)
            if node.kind.isContainer, collapsed.contains(node.id) {
                i = node.subtreeEnd
            } else {
                i += 1
            }
        }
        return out
    }

    /// Dastlab `depth >= limit` konteynerlar yig'iq — katta javob bir ekranga sig'adi,
    /// yuqori tuzilma esa darhol ko'rinadi.
    public func defaultCollapsed(depthLimit: Int = JSONTree.defaultExpandedDepth) -> Set<String> {
        Set(nodes.filter { $0.kind.isContainer && $0.depth >= depthLimit && $0.childCount > 0 }.map(\.id))
    }

    public func node(id: String) -> JSONNode? {
        nodes.first { $0.id == id }
    }

    /// Tugunning barcha avlod-konteynerlari (o'zi bilan) — ⌥-bosishda butun shox yig'iladi/yoyiladi.
    public func subtreeContainerIDs(of id: String) -> Set<String> {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return [] }
        let node = nodes[index]
        return Set(nodes[index..<node.subtreeEnd].filter { $0.kind.isContainer && $0.childCount > 0 }.map(\.id))
    }

    /// Ota konteynerlar — topilmaga sakrashda ular yoyilgan bo'lishi kerak.
    public func ancestorIDs(of id: String) -> [String] {
        guard let node = node(id: id) else { return [] }
        var out: [String] = []
        for n in 0..<node.components.count {
            out.append(JSONTree.path(Array(node.components.prefix(n))))
        }
        return out
    }

    /// Kalit yoki qiymatida so'rov uchraydigan tugunlar (DFS tartibida).
    public func matches(query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return nodes.filter { node in
            node.key.localizedCaseInsensitiveContains(q)
                || (node.scalar?.localizedCaseInsensitiveContains(q) ?? false)
        }.map(\.id)
    }

    /// Tugun qiymati JSON matni sifatida: konteyner — formatlangan, skalyar — o'zi (satr tirnoqsiz).
    public func valueText(id: String) -> String? {
        guard let node = node(id: id) else { return nil }
        var cursor: Any = root
        for c in node.components {
            switch c {
            case .key(let k):
                guard let dict = cursor as? [String: Any], let next = dict[k] else { return nil }
                cursor = next
            case .index(let i):
                guard let arr = cursor as? [Any], i < arr.count else { return nil }
                cursor = arr[i]
            }
        }
        if node.kind.isContainer {
            guard let data = try? JSONSerialization.data(withJSONObject: cursor, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        if let s = cursor as? String { return s }
        return node.scalar
    }
}
