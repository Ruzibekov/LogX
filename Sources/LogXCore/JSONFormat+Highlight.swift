import Foundation

public enum JSONSpanKind: String, Sendable, Equatable {
    case key, string, number, boolNull, punct, plain
}

public struct JSONRun: Equatable, Sendable {
    public var length: Int
    public var kind: JSONSpanKind

    public init(length: Int, kind: JSONSpanKind) {
        self.length = length
        self.kind = kind
    }
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
        guard !text.isEmpty else { return [] }
        var out: [JSONSpan] = []
        out.reserveCapacity(64)
        var cursor = text.startIndex
        let utf16View = text.utf16
        var utf16Cursor = utf16View.startIndex
        for run in highlightRuns(text) {
            guard let end = utf16View.index(utf16Cursor, offsetBy: run.length, limitedBy: utf16View.endIndex),
                  let endIndex = end.samePosition(in: text) else { break }
            out.append(JSONSpan(String(text[cursor..<endIndex]), run.kind))
            cursor = endIndex
            utf16Cursor = end
        }
        return out
    }

    public static func highlightRuns(_ text: String) -> [JSONRun] {
        if text.isEmpty { return [] }
        var spans: [JSONRun] = []
        var i = text.startIndex

        func push(_ start: String.Index, _ end: String.Index, _ kind: JSONSpanKind) {
            guard start < end else { return }
            let length = text[start..<end].utf16.count
            if kind == .plain, let last = spans.last, last.kind == .plain {
                spans[spans.count - 1].length += length
            } else {
                spans.append(JSONRun(length: length, kind: kind))
            }
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
        return spans
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

    public static func highlightHeaderRuns(_ text: String) -> [JSONRun] {
        highlightHeaders(text).map { JSONRun(length: ($0.text as NSString).length, kind: $0.kind) }
    }
}
