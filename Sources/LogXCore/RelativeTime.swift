import Foundation

/// Jonli ro'yxat uchun relative vaqt: "endi", "5s", "12daq", "3soat", "2kun".
public enum RelativeTime {
    public static func label(ts: Double?, now: Date = Date()) -> String {
        guard let ts else { return "—" }
        let seconds = ts > 10_000_000_000 ? ts / 1000 : ts
        let delta = max(0, now.timeIntervalSince1970 - seconds)
        if delta < 5 { return "endi" }
        if delta < 60 { return "\(Int(delta))s" }
        if delta < 3600 { return "\(Int(delta / 60))daq" }
        if delta < 86_400 { return "\(Int(delta / 3600))soat" }
        return "\(Int(delta / 86_400))kun"
    }

    /// So'rov "yangi" deb ko'rinadigan oyna (sekund).
    public static let freshWindow: TimeInterval = 8

    public static func isFresh(ts: Double?, now: Date = Date()) -> Bool {
        guard let ts else { return false }
        let seconds = ts > 10_000_000_000 ? ts / 1000 : ts
        return now.timeIntervalSince1970 - seconds < freshWindow
    }

    public static func clock(ts: Double?, timeZone: TimeZone = .current) -> String {
        guard let ts else { return "—" }
        let seconds = ts > 10_000_000_000 ? ts / 1000 : ts
        let date = Date(timeIntervalSince1970: seconds)
        clockLock.lock()
        defer { clockLock.unlock() }
        clockFormatter.timeZone = timeZone
        return clockFormatter.string(from: date)
    }

    /// Detal uchun to'liq vaqt: kun.oy soat:daqiqa:soniya.millisekund.
    public static func stamp(ts: Double?, timeZone: TimeZone = .current) -> String {
        guard let ts else { return "—" }
        let seconds = ts > 10_000_000_000 ? ts / 1000 : ts
        let date = Date(timeIntervalSince1970: seconds)
        clockLock.lock()
        defer { clockLock.unlock() }
        stampFormatter.timeZone = timeZone
        return stampFormatter.string(from: date)
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    private static let clockLock = NSLock()
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()
}
