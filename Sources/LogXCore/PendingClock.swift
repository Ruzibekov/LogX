import Foundation

public enum PendingClock {
    public static let staleAfter: TimeInterval = 120

    public static func isStale(ts: Double?, now: Date = Date()) -> Bool {
        guard let seconds = elapsed(ts: ts, now: now) else { return false }
        return seconds >= staleAfter
    }

    public static func title(ts: Double?, now: Date = Date()) -> String {
        isStale(ts: ts, now: now) ? "Javob kelmadi" : StatusClass.pending.title
    }

    public static func sentAt(ts: Double?) -> Date? {
        guard let ts, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts > 10_000_000_000 ? ts / 1000 : ts)
    }

    public static func staleAt(ts: Double?) -> Date? {
        sentAt(ts: ts)?.addingTimeInterval(staleAfter)
    }

    public static func elapsed(ts: Double?, now: Date = Date()) -> TimeInterval? {
        guard let sent = sentAt(ts: ts) else { return nil }
        return max(0, now.timeIntervalSince(sent))
    }

    public static func label(ts: Double?, now: Date = Date()) -> String {
        guard let seconds = elapsed(ts: ts, now: now) else { return "…" }
        if seconds < 10 { return String(format: "%.1f s", seconds) }
        if seconds < 60 { return "\(Int(seconds)) s" }
        let whole = Int(seconds)
        return "\(whole / 60)m \(whole % 60)s"
    }
}

extension NetworkLog {
    public var statusCodeLabel: String {
        if isPending { return "···" }
        return responseCode.map(String.init) ?? "NET"
    }
}
