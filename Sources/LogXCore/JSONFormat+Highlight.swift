import Foundation

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

extension JSONFormat {
    public static func highlight(_ text: String) -> [JSONSpan] {
        if text.isEmpty { return [] }
        var spans: [JSONSpan] = []
        var i = text.startIndex

        func push(_ start: String.Index, _ end: String.Index, _ kind: JSONSpanKind) {
            if start < end { spans.append(JSONSpan(String(text[start..<end]), kind)) }
        }
        func isWord(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        func boundary(_ idx: String.Index) -> Bool {
            idx == text.startIndex || !isWord(text[text.index(before: idx)])
        }
        func numberStart(_ idx: String.Index) -> Bool {
            guard boundary(idx) else { return false }
            let c = text[idx]
            if c.isNumber { return true }
            guard c == "-" else { return false }
            let next = text.index(after: idx)
            return next < text.endIndex && text[next].isNumber
        }
        func keyword(_ idx: String.Index) -> String? {
            guard boundary(idx) else { return nil }
            for w in ["true", "false", "null"] where text[idx...].hasPrefix(w) {
                let end = text.index(idx, offsetBy: w.count)
                if end == text.endIndex || !isWord(text[end]) { return w }
            }
            return nil
        }
        func isPunct(_ c: Character) -> Bool {
            c == "{" || c == "[" || c == "}" || c == "]" || c == ":" || c == ","
        }

        func canOpenQuote(_ idx: String.Index) -> Bool {
            var p = idx
            while p > text.startIndex {
                p = text.index(before: p)
                let c = text[p]
                if c.isWhitespace { continue }
                return c == "{" || c == "[" || c == "," || c == ":"
            }
            return true
        }

        while i < text.endIndex {
            let ch = text[i]
            if ch == "\"" {
                if !canOpenQuote(i) {
                    push(i, text.index(after: i), .punct)
                    i = text.index(after: i)
                    continue
                }
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
            if isPunct(ch) {
                push(i, text.index(after: i), .punct)
                i = text.index(after: i)
                continue
            }
            if numberStart(i) {
                let start = i
                i = text.index(after: i)
                while i < text.endIndex, "0123456789+-.eE".contains(text[i]) {
                    i = text.index(after: i)
                }
                push(start, i, .number)
                continue
            }
            if let word = keyword(i) {
                let end = text.index(i, offsetBy: word.count)
                push(i, end, .boolNull)
                i = end
                continue
            }
            let start = i
            i = text.index(after: i)
            while i < text.endIndex {
                let c = text[i]
                if c == "\"" || isPunct(c) { break }
                if numberStart(i) || keyword(i) != nil { break }
                i = text.index(after: i)
            }
            push(start, i, .plain)
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
