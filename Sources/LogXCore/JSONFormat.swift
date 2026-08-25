import Foundation

public enum DetailTab: String, CaseIterable, Sendable {
    case response
    case request
    case headers
    case params

    public var title: String {
        switch self {
        case .response: return "Javob"
        case .request: return "So'rov"
        case .headers: return "Sarlavhalar"
        case .params: return "Parametrlar"
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

        if let data = s.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            if (obj is [String: Any]) || (obj is [Any]) {
                if #available(macOS 10.15, *) {
                    if let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
                       let text = String(data: out, encoding: .utf8),
                       !text.isEmpty {
                        return text
                    }
                }
                if let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                   let text = String(data: out, encoding: .utf8),
                   !text.isEmpty {
                    return text
                }
            } else if let str = obj as? String {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
                    let formatted = pretty(trimmed)
                    if formatted.contains("\n") { return formatted }
                }
            }
        }

        if s.contains("{") || s.contains("[") {
            let formatted = formatJSONFallback(s)
            if formatted.contains("\n") {
                return formatted
            }
        }

        return s
    }

    public static func formatJSONFallback(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        guard text.contains("{") || text.contains("[") else { return text }

        var result = ""
        result.reserveCapacity(text.count * 2)
        var indent = 0
        var inQuote: Character? = nil
        var isEscaped = false
        var i = text.startIndex

        while i < text.endIndex {
            let ch = text[i]

            if isEscaped {
                result.append(ch)
                isEscaped = false
                i = text.index(after: i)
                continue
            }

            if inQuote != nil && ch == "\\" {
                result.append(ch)
                isEscaped = true
                i = text.index(after: i)
                continue
            }

            if ch == "\"" || ch == "'" {
                if inQuote == ch {
                    inQuote = nil
                } else if inQuote == nil {
                    inQuote = ch
                }
                result.append(ch)
                i = text.index(after: i)
                continue
            }

            if inQuote != nil {
                result.append(ch)
                i = text.index(after: i)
                continue
            }

            if ch.isWhitespace {
                i = text.index(after: i)
                continue
            }

            if ch == "{" || ch == "[" {
                var nextIdx = text.index(after: i)
                while nextIdx < text.endIndex && text[nextIdx].isWhitespace {
                    nextIdx = text.index(after: nextIdx)
                }
                let closing: Character = ch == "{" ? "}" : "]"
                if nextIdx < text.endIndex && text[nextIdx] == closing {
                    result.append(ch)
                    result.append(closing)
                    i = text.index(after: nextIdx)
                    continue
                }

                indent += 1
                result.append(ch)
                result.append("\n")
                result.append(String(repeating: "  ", count: indent))
                i = text.index(after: i)
                continue
            }

            if ch == "}" || ch == "]" {
                indent = max(0, indent - 1)
                while result.hasSuffix(" ") || result.hasSuffix("\t") {
                    result.removeLast()
                }
                if !result.hasSuffix("\n") {
                    result.append("\n")
                }
                result.append(String(repeating: "  ", count: indent))
                result.append(ch)
                i = text.index(after: i)
                continue
            }

            if ch == "," {
                while result.hasSuffix(" ") || result.hasSuffix("\t") {
                    result.removeLast()
                }
                result.append(",")
                result.append("\n")
                result.append(String(repeating: "  ", count: indent))
                i = text.index(after: i)
                continue
            }

            if ch == ":" {
                while result.hasSuffix(" ") || result.hasSuffix("\t") {
                    result.removeLast()
                }
                result.append(": ")
                i = text.index(after: i)
                continue
            }

            result.append(ch)
            i = text.index(after: i)
        }

        return result
    }

    public static func headersText(request: [String: String], response: [String: String]) -> String {
        func block(_ title: String, _ map: [String: String]) -> String {
            let lines = map.keys.sorted().map { "\($0): \(map[$0] ?? "")" }
            return ([title] + (lines.isEmpty ? ["—"] : lines)).joined(separator: "\n")
        }
        return [block("SO'ROV SARLAVHALARI", request), "", block("JAVOB SARLAVHALARI", response)].joined(separator: "\n")
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

    public static func highlightHeaders(_ text: String) -> [JSONSpan] {
        guard !text.isEmpty else { return [] }
        var spans: [JSONSpan] = []
        let lines = text.components(separatedBy: "\n")
        for (offset, line) in lines.enumerated() {
            if line.isEmpty {
                if offset < lines.count - 1 { spans.append(JSONSpan("\n", .punct)) }
                continue
            }
            guard let idx = line.firstIndex(of: ":") else {
                spans.append(JSONSpan(line, .plain))
                if offset < lines.count - 1 { spans.append(JSONSpan("\n", .punct)) }
                continue
            }
            spans.append(JSONSpan(String(line[..<idx]), .key))
            spans.append(JSONSpan(":", .punct))
            spans.append(JSONSpan(String(line[line.index(after: idx)...]), .string))
            if offset < lines.count - 1 { spans.append(JSONSpan("\n", .punct)) }
        }
        return spans
    }

    public static func body(for log: NetworkLog, tab: DetailTab) -> String {
        switch tab {
        case .request:
            return pretty(log.requestBody)
        case .response:
            let raw = pretty(log.responseBody)
            if !raw.isEmpty { return raw }
            let fallbackMsg = [log.error, log.responseMessage, log.responseBodyMessage].compactMap { $0 }.first ?? ""
            return pretty(fallbackMsg)
        case .headers:
            return headersText(request: log.requestHeaders, response: log.responseHeaders)
        case .params:
            if log.queryParams.isEmpty { return "" }
            return log.queryParams.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
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
