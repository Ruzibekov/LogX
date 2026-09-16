import AppKit
import Foundation
import SwiftUI

public enum URLSpanKind: String, Sendable, Equatable {
    case scheme
    case host
    case port
    case pathPrefix
    case pathEndpoint
    case queryMark
    case paramKey
    case paramEquals
    case paramValue
    case paramAmp
    case fragment
    case plain
}

public struct URLSpan: Sendable, Equatable {
    public var text: String
    public var kind: URLSpanKind

    public init(_ text: String, _ kind: URLSpanKind) {
        self.text = text
        self.kind = kind
    }
}

public enum URLHighlighter: Sendable {
    public static func tokenize(_ raw: String) -> [URLSpan] {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        var spans: [URLSpan] = []
        var cursor = text.startIndex

        if let colonSlash = text.range(of: "://") {
            let schemeEnd = colonSlash.upperBound
            spans.append(URLSpan(String(text[..<schemeEnd]), .scheme))
            cursor = schemeEnd

            let rest = text[cursor...]
            let hostEnd = rest.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? text.endIndex
            let hostPort = String(text[cursor..<hostEnd])
            cursor = hostEnd

            if let colonIdx = hostPort.firstIndex(of: ":"), colonIdx != hostPort.startIndex {
                let hostStr = String(hostPort[..<colonIdx])
                let portStr = String(hostPort[colonIdx...])
                spans.append(URLSpan(hostStr, .host))
                spans.append(URLSpan(portStr, .port))
            } else if !hostPort.isEmpty {
                spans.append(URLSpan(hostPort, .host))
            }
        }

        if cursor < text.endIndex, text[cursor] != "?", text[cursor] != "#" {
            let rest = text[cursor...]
            let pathEnd = rest.firstIndex(where: { $0 == "?" || $0 == "#" }) ?? text.endIndex
            let pathStr = String(text[cursor..<pathEnd])
            cursor = pathEnd
            tokenizePath(pathStr, into: &spans)
        }

        if cursor < text.endIndex, text[cursor] == "?" {
            spans.append(URLSpan("?", .queryMark))
            cursor = text.index(after: cursor)
            let rest = text[cursor...]
            let queryEnd = rest.firstIndex(of: "#") ?? text.endIndex
            let queryStr = String(text[cursor..<queryEnd])
            cursor = queryEnd
            tokenizeQuery(queryStr, into: &spans)
        }

        if cursor < text.endIndex, text[cursor] == "#" {
            spans.append(URLSpan(String(text[cursor...]), .fragment))
            cursor = text.endIndex
        }

        if spans.isEmpty {
            spans.append(URLSpan(text, .plain))
        }

        return spans
    }

    private static func tokenizePath(_ path: String, into spans: inout [URLSpan]) {
        guard !path.isEmpty else { return }
        if path == "/" {
            spans.append(URLSpan("/", .pathPrefix))
            return
        }

        let patterns = [
            #"^/(?:api/)?v\d+/"#,
            #"^/api/"#
        ]
        for pattern in patterns {
            if let range = path.range(of: pattern, options: .regularExpression) {
                let prefix = String(path[..<range.upperBound])
                let endpoint = String(path[range.upperBound...])
                spans.append(URLSpan(prefix, .pathPrefix))
                if !endpoint.isEmpty {
                    spans.append(URLSpan(endpoint, .pathEndpoint))
                }
                return
            }
        }

        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        let meaningful = segments.filter { !$0.isEmpty }
        if meaningful.count <= 1 {
            spans.append(URLSpan(path, .pathEndpoint))
            return
        }

        let lastSegment = String(meaningful.last ?? "")
        let isIdLeaf = Int(lastSegment) != nil || (lastSegment.count == 36 && lastSegment.contains("-"))
        let endpointCount = (meaningful.count >= 2 && isIdLeaf) ? 2 : 1
        let prefixComponents = meaningful.dropLast(endpointCount)
        let prefixStr = "/" + prefixComponents.joined(separator: "/") + "/"
        let endpointStr = meaningful.suffix(endpointCount).joined(separator: "/")

        spans.append(URLSpan(prefixStr, .pathPrefix))
        spans.append(URLSpan(endpointStr, .pathEndpoint))
    }

    private static func tokenizeQuery(_ query: String, into spans: inout [URLSpan]) {
        guard !query.isEmpty else { return }
        let pairs = query.split(separator: "&", omittingEmptySubsequences: false)
        for (i, pair) in pairs.enumerated() {
            if i > 0 {
                spans.append(URLSpan("&", .paramAmp))
            }
            if let eq = pair.firstIndex(of: "=") {
                let k = String(pair[..<eq])
                let v = String(pair[pair.index(after: eq)...])
                spans.append(URLSpan(k, .paramKey))
                spans.append(URLSpan("=", .paramEquals))
                if !v.isEmpty {
                    spans.append(URLSpan(v, .paramValue))
                }
            } else {
                spans.append(URLSpan(String(pair), .paramKey))
            }
        }
    }

    public static func nsColor(for kind: URLSpanKind, selected: Bool = false) -> NSColor {
        switch kind {
        case .scheme:
            return NSColor(srgbRed: 0.420, green: 0.470, blue: 0.540, alpha: 1)
        case .host:
            return NSColor(srgbRed: 0.560, green: 0.610, blue: 0.680, alpha: 1)
        case .port:
            return NSColor(srgbRed: 0.720, green: 0.640, blue: 0.480, alpha: 1)
        case .pathPrefix:
            return selected
                ? NSColor(srgbRed: 0.720, green: 0.760, blue: 0.820, alpha: 1)
                : NSColor(srgbRed: 0.480, green: 0.530, blue: 0.600, alpha: 1)
        case .pathEndpoint:
            return selected
                ? NSColor(srgbRed: 0.990, green: 0.990, blue: 1.000, alpha: 1)
                : NSColor(srgbRed: 0.920, green: 0.940, blue: 0.970, alpha: 1)
        case .queryMark, .paramEquals, .paramAmp:
            return NSColor(srgbRed: 0.380, green: 0.420, blue: 0.480, alpha: 1)
        case .paramKey:
            return selected
                ? NSColor(srgbRed: 0.700, green: 0.750, blue: 0.850, alpha: 1)
                : NSColor(srgbRed: 0.580, green: 0.640, blue: 0.720, alpha: 1)
        case .paramValue:
            return selected
                ? NSColor(srgbRed: 0.850, green: 0.890, blue: 0.940, alpha: 1)
                : NSColor(srgbRed: 0.740, green: 0.780, blue: 0.840, alpha: 1)
        case .fragment:
            return NSColor(srgbRed: 0.620, green: 0.600, blue: 0.700, alpha: 1)
        case .plain:
            return NSColor(srgbRed: 0.820, green: 0.840, blue: 0.870, alpha: 1)
        }
    }

    public static func color(for kind: URLSpanKind, selected: Bool = false) -> Color {
        Color(nsColor: nsColor(for: kind, selected: selected))
    }

    public static func fontWeight(for kind: URLSpanKind, selected: Bool = false) -> Font.Weight {
        switch kind {
        case .pathEndpoint: return selected ? .bold : .semibold
        case .paramKey: return .medium
        case .host: return .medium
        default: return .regular
        }
    }

    public static func attributed(
        _ urlString: String,
        baseFontSize: CGFloat = 11,
        selected: Bool = false
    ) -> AttributedString {
        let key = AttributedCache.Key(text: urlString, size: baseFontSize, selected: selected)
        if let hit = AttributedCache.value(key) { return hit }
        let built = build(urlString, baseFontSize: baseFontSize, selected: selected)
        AttributedCache.store(key, built)
        return built
    }

    /// Ro'yxatning har kadrida qayta yig'ilmasin: chegaralangan xotira (`AttributedCache.capacity`)
    /// varaqlashdagi ajratishlarni kesadi, o'zi esa cheksiz o'smaydi.
    public static func clearCache() { AttributedCache.clear() }

    static func build(
        _ urlString: String,
        baseFontSize: CGFloat,
        selected: Bool
    ) -> AttributedString {
        let spans = tokenize(urlString)
        var result = AttributedString()
        for span in spans {
            var piece = AttributedString(span.text)
            piece.font = .system(
                size: baseFontSize,
                weight: fontWeight(for: span.kind, selected: selected),
                design: .monospaced
            )
            piece.foregroundColor = color(for: span.kind, selected: selected)
            result.append(piece)
        }
        return result
    }
}

enum AttributedCache {
    struct Key: Hashable {
        let text: String
        let size: CGFloat
        let selected: Bool
    }

    static let capacity = 512
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [Key: AttributedString] = [:]

    static func value(_ key: Key) -> AttributedString? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    static func store(_ key: Key, _ value: AttributedString) {
        lock.lock()
        defer { lock.unlock() }
        if storage.count >= capacity { storage.removeAll(keepingCapacity: true) }
        storage[key] = value
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll(keepingCapacity: false)
    }

    static var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}
