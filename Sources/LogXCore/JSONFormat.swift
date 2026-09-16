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

public enum JSONFormat {
    public static func pretty(_ raw: String?) -> String {
        let s = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }

        if let data = s.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            if (obj is [String: Any]) || (obj is [Any]) {
                if let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
                   let text = String(data: out, encoding: .utf8),
                   !text.isEmpty {
                    return text
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

    private static func canOpenQuote(at idx: String.Index, in text: String) -> Bool {
        var p = idx
        while p > text.startIndex {
            p = text.index(before: p)
            let ch = text[p]
            if ch.isWhitespace { continue }
            return ch == "{" || ch == "[" || ch == "," || ch == ":"
        }
        return true
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

            if inQuote != nil && ch == "\n" {
                var nextIdx = text.index(after: i)
                while nextIdx < text.endIndex && (text[nextIdx] == " " || text[nextIdx] == "\t") {
                    nextIdx = text.index(after: nextIdx)
                }
                if nextIdx < text.endIndex {
                    let nextCh = text[nextIdx]
                    if nextCh == "}" || nextCh == "]" || nextCh == "{" || nextCh == "[" || nextCh == "," {
                        inQuote = nil
                    }
                }
            }

            if ch == "\"" || ch == "'" {
                if inQuote == ch {
                    if ch == "'" && i > text.startIndex && text.index(after: i) < text.endIndex,
                       text[text.index(before: i)].isLetter && text[text.index(after: i)].isLetter {
                        result.append(ch)
                        i = text.index(after: i)
                        continue
                    }
                    inQuote = nil
                } else if inQuote == nil {
                    if canOpenQuote(at: i, in: text) {
                        inQuote = ch
                    }
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

    /// `pretty == false` — tana serverdan kelgan shaklida (kalit tartibi, bo'shliq) ko'rsatiladi.
    public static func body(for log: NetworkLog, tab: DetailTab, redact: Bool = false, pretty: Bool = true) -> String {
        switch tab {
        case .request:
            return render(log.requestBody, redact: redact, pretty: pretty)
        case .response:
            let raw = log.responseBody ?? ""
            let source = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ([log.error, log.responseMessage, log.responseBodyMessage].compactMap { $0 }.first ?? "")
                : raw
            return render(source, redact: redact, pretty: pretty)
        case .headers:
            let request = redact ? Redactor.mask(log.requestHeaders) : log.requestHeaders
            let response = redact ? Redactor.mask(log.responseHeaders) : log.responseHeaders
            return headersText(request: request, response: response)
        case .params:
            let params = redact ? Redactor.maskParams(log.queryParams) : log.queryParams
            if params.isEmpty { return "" }
            return params.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }
    }

    private static func render(_ source: String?, redact: Bool, pretty: Bool) -> String {
        if pretty {
            return self.pretty(redact ? Redactor.redactBody(source) : source)
        }
        let text = (source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return redact ? (Redactor.redactBody(text, preserveFormat: true) ?? text) : text
    }
}
