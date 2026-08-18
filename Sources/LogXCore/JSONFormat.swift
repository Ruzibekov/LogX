import Foundation

public enum DetailTab: String, CaseIterable, Sendable {
    case request
    case response
    case headers

    public var title: String {
        switch self {
        case .request: return "Request"
        case .response: return "Response"
        case .headers: return "Header"
        }
    }
}

public enum JSONSpanKind: String, Sendable, Equatable {
    case key, string, number, boolNull, punct, plain
}

public struct JSONSpan: Equatable, Sendable {
    public var text: String
    public var kind: JSONSpanKind

    public init(_ text: String, _ kind: JSONSpanKind) {
        self.text = text
        self.kind = kind
    }
}

public enum JSONFormat {
    public static func pretty(_ raw: String?) -> String {
        let s = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        guard let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: out, encoding: .utf8)
        else { return s }
        return text
    }

    public static func headersText(request: [String: String], response: [String: String]) -> String {
        func block(_ title: String, _ map: [String: String]) -> String {
            let lines = map.keys.sorted().map { "\($0): \(map[$0] ?? "")" }
            return ([title] + (lines.isEmpty ? ["—"] : lines)).joined(separator: "\n")
        }
        return [block("REQUEST", request), "", block("RESPONSE", response)].joined(separator: "\n")
    }

    public static func highlight(_ text: String) -> [JSONSpan] {
        if text.isEmpty { return [] }
        var spans: [JSONSpan] = []
        var i = text.startIndex
        var expectingKey = false
        var stack: [Bool] = []

        func push(_ start: String.Index, _ end: String.Index, _ kind: JSONSpanKind) {
            if start < end { spans.append(JSONSpan(String(text[start..<end]), kind)) }
        }

        while i < text.endIndex {
            let ch = text[i]
            if ch == "\"" {
                let start = i
                i = text.index(after: i)
                while i < text.endIndex {
                    if text[i] == "\\" {
                        i = text.index(after: i)
                        if i < text.endIndex { i = text.index(after: i) }
                        continue
                    }
                    if text[i] == "\"" {
                        i = text.index(after: i)
                        break
                    }
                    i = text.index(after: i)
                }
                var j = i
                while j < text.endIndex, text[j].isWhitespace { j = text.index(after: j) }
                let isKey = j < text.endIndex && text[j] == ":"
                push(start, i, isKey ? .key : .string)
                continue
            }
            if ch == "{" || ch == "[" {
                stack.append(ch == "{")
                expectingKey = ch == "{"
                push(i, text.index(after: i), .punct)
                i = text.index(after: i)
                continue
            }
            if ch == "}" || ch == "]" {
                if !stack.isEmpty { stack.removeLast() }
                expectingKey = stack.last == true
                push(i, text.index(after: i), .punct)
                i = text.index(after: i)
                continue
            }
            if ch == ":" || ch == "," {
                expectingKey = ch == "," && stack.last == true
                push(i, text.index(after: i), .punct)
                i = text.index(after: i)
                continue
            }
            if ch.isNumber || ch == "-" {
                let start = i
                while i < text.endIndex, "0123456789+-.eE".contains(text[i]) {
                    i = text.index(after: i)
                }
                push(start, i, .number)
                continue
            }
            if text[i...].hasPrefix("true") || text[i...].hasPrefix("null") {
                let word = text[i...].hasPrefix("true") ? "true" : "null"
                let end = text.index(i, offsetBy: word.count)
                push(i, end, .boolNull)
                i = end
                continue
            }
            if text[i...].hasPrefix("false") {
                let end = text.index(i, offsetBy: 5)
                push(i, end, .boolNull)
                i = end
                continue
            }
            let start = i
            i = text.index(after: i)
            while i < text.endIndex {
                let c = text[i]
                if c == "\"" || c == "{" || c == "}" || c == "[" || c == "]" || c == ":" || c == "," || c.isNumber || c == "-" {
                    break
                }
                if text[i...].hasPrefix("true") || text[i...].hasPrefix("false") || text[i...].hasPrefix("null") {
                    break
                }
                i = text.index(after: i)
            }
            push(start, i, .plain)
            _ = expectingKey
        }
        return mergePlain(spans)
    }

    public static func body(for log: NetworkLog, tab: DetailTab) -> String {
        switch tab {
        case .request:
            return pretty(log.requestBody)
        case .response:
            let raw = pretty(log.responseBody)
            if !raw.isEmpty { return raw }
            return [log.error, log.responseMessage].compactMap { $0 }.first ?? ""
        case .headers:
            return headersText(request: log.requestHeaders, response: log.responseHeaders)
        }
    }

    public static func shareCaption(log: NetworkLog, tab: DetailTab) -> String {
        let code = log.responseCode.map(String.init) ?? "NET"
        let url = log.url.isEmpty ? log.api : log.url
        return "LogX · \(log.method) \(code) · \(tab.title)\n\(url)"
    }

    private static func mergePlain(_ spans: [JSONSpan]) -> [JSONSpan] {
        var out: [JSONSpan] = []
        for s in spans {
            if s.text.isEmpty { continue }
            if let last = out.last, last.kind == s.kind, s.kind == .plain {
                out[out.count - 1].text += s.text
            } else {
                out.append(s)
            }
        }
        return out
    }
}
