import Foundation

public enum DiffOp: Equatable, Sendable {
    case same, insert, delete, gap
}

public struct DiffLine: Equatable, Sendable {
    public var op: DiffOp
    public var text: String
    public var oldLine: Int?
    public var newLine: Int?

    public init(op: DiffOp, text: String, oldLine: Int? = nil, newLine: Int? = nil) {
        self.op = op
        self.text = text
        self.oldLine = oldLine
        self.newLine = newLine
    }
}

/// Qatorlar bo'yicha diff: umumiy bosh/oxir kesiladi, o'rtasi LCS bilan
/// tekislanadi. O'rta qism `cellLimit` dan katta bo'lsa u butunlay
/// «o'chdi + qo'shildi» deb ko'rsatiladi — UI hech qachon muzlamaydi.
public struct TextDiff: Equatable, Sendable {
    public static let cellLimit = 4_000_000

    public var lines: [DiffLine]
    public var inserted: Int
    public var deleted: Int
    public var truncated: Bool

    public var identical: Bool { inserted == 0 && deleted == 0 }

    public static func lines(old: String, new: String) -> TextDiff {
        let a = split(old)
        let b = split(new)
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }

        var out: [DiffLine] = []
        out.reserveCapacity(a.count + b.count - prefix)
        for i in 0..<prefix {
            out.append(DiffLine(op: .same, text: a[i], oldLine: i + 1, newLine: i + 1))
        }
        let midA = Array(a[prefix..<(a.count - suffix)])
        let midB = Array(b[prefix..<(b.count - suffix)])
        var truncated = false
        let middle: [DiffLine]
        if midA.count * midB.count > cellLimit {
            truncated = true
            middle = midA.enumerated().map { DiffLine(op: .delete, text: $1, oldLine: prefix + $0 + 1) }
                + midB.enumerated().map { DiffLine(op: .insert, text: $1, newLine: prefix + $0 + 1) }
        } else {
            middle = lcs(midA, midB, oldBase: prefix, newBase: prefix)
        }
        out.append(contentsOf: middle)
        for i in 0..<suffix {
            let ai = a.count - suffix + i
            let bi = b.count - suffix + i
            out.append(DiffLine(op: .same, text: a[ai], oldLine: ai + 1, newLine: bi + 1))
        }
        let ins = out.reduce(0) { $0 + ($1.op == .insert ? 1 : 0) }
        let del = out.reduce(0) { $0 + ($1.op == .delete ? 1 : 0) }
        return TextDiff(lines: out, inserted: ins, deleted: del, truncated: truncated)
    }

    private static func split(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return text.components(separatedBy: "\n")
    }

    private static func lcs(_ a: [String], _ b: [String], oldBase: Int, newBase: Int) -> [DiffLine] {
        let n = a.count
        let m = b.count
        if n == 0 {
            return b.enumerated().map { DiffLine(op: .insert, text: $1, newLine: newBase + $0 + 1) }
        }
        if m == 0 {
            return a.enumerated().map { DiffLine(op: .delete, text: $1, oldLine: oldBase + $0 + 1) }
        }
        let width = m + 1
        var table = [Int32](repeating: 0, count: (n + 1) * width)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if a[i] == b[j] {
                    table[i * width + j] = table[(i + 1) * width + j + 1] + 1
                } else {
                    table[i * width + j] = max(table[(i + 1) * width + j], table[i * width + j + 1])
                }
            }
        }
        var out: [DiffLine] = []
        var i = 0
        var j = 0
        while i < n, j < m {
            if a[i] == b[j] {
                out.append(DiffLine(op: .same, text: a[i], oldLine: oldBase + i + 1, newLine: newBase + j + 1))
                i += 1
                j += 1
            } else if table[(i + 1) * width + j] >= table[i * width + j + 1] {
                out.append(DiffLine(op: .delete, text: a[i], oldLine: oldBase + i + 1))
                i += 1
            } else {
                out.append(DiffLine(op: .insert, text: b[j], newLine: newBase + j + 1))
                j += 1
            }
        }
        while i < n {
            out.append(DiffLine(op: .delete, text: a[i], oldLine: oldBase + i + 1))
            i += 1
        }
        while j < m {
            out.append(DiffLine(op: .insert, text: b[j], newLine: newBase + j + 1))
            j += 1
        }
        return out
    }

    /// Faqat farqlar: har o'zgarish atrofida `context` qator, oradagi bir xil
    /// bloklar `gap` qatoriga yig'iladi.
    public func compact(context: Int = 3) -> [DiffLine] {
        guard !identical else { return [] }
        var keep = [Bool](repeating: false, count: lines.count)
        for (i, line) in lines.enumerated() where line.op != .same {
            let lo = max(0, i - context)
            let hi = min(lines.count - 1, i + context)
            for k in lo...hi { keep[k] = true }
        }
        var out: [DiffLine] = []
        var hidden = 0
        for (i, line) in lines.enumerated() {
            if keep[i] {
                if hidden > 0 {
                    out.append(DiffLine(op: .gap, text: "⋯ \(hidden) qator bir xil"))
                    hidden = 0
                }
                out.append(line)
            } else {
                hidden += 1
            }
        }
        if hidden > 0 {
            out.append(DiffLine(op: .gap, text: "⋯ \(hidden) qator bir xil"))
        }
        return out
    }

    /// Unified matn: `+`/`-`/` ` prefiksli qatorlar — nusxalash va eksport uchun.
    public static func unified(_ lines: [DiffLine]) -> String {
        lines.map { line in
            switch line.op {
            case .same: return "  " + line.text
            case .insert: return "+ " + line.text
            case .delete: return "- " + line.text
            case .gap: return line.text
            }
        }.joined(separator: "\n")
    }
}

/// Ikki so'rovni solishtirish uchun tanlangan matn juftligi.
public enum LogDiff {
    public enum Section: String, CaseIterable, Sendable {
        case response, request, headers, url

        public var title: String {
            switch self {
            case .response: return "Javob"
            case .request: return "So'rov"
            case .headers: return "Sarlavhalar"
            case .url: return "URL"
            }
        }
    }

    public static func text(for log: NetworkLog, section: Section, redact: Bool) -> String {
        switch section {
        case .response: return JSONFormat.body(for: log, tab: .response, redact: redact, pretty: true)
        case .request: return JSONFormat.body(for: log, tab: .request, redact: redact, pretty: true)
        case .headers: return JSONFormat.body(for: log, tab: .headers, redact: redact, pretty: true)
        case .url:
            let raw = log.url.isEmpty ? log.api : log.url
            let url = redact ? Redactor.maskURL(raw) : raw
            let params = redact ? Redactor.maskParams(log.queryParams) : log.queryParams
            let lines = ["\(log.method.uppercased()) \(url)"] + params.map { "\($0.key) = \($0.value)" }
            return lines.joined(separator: "\n")
        }
    }

    public static func diff(_ a: NetworkLog, _ b: NetworkLog, section: Section, redact: Bool) -> TextDiff {
        TextDiff.lines(old: text(for: a, section: section, redact: redact), new: text(for: b, section: section, redact: redact))
    }

    /// Ro'yxatda (yangi → eski) shu so'rovdan oldingi ayni endpoint chaqiruvi.
    public static func previousSameEndpoint(of log: NetworkLog, in logs: [NetworkLog]) -> NetworkLog? {
        guard let index = logs.firstIndex(where: { $0.key == log.key }) else { return nil }
        let identity = EndpointIdentity.key(for: log)
        return logs[(index + 1)...].first { EndpointIdentity.key(for: $0) == identity }
    }
}
