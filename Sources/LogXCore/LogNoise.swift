import Foundation

public enum LogNoise {
    public static let slowThresholdMs = 800

    private static let hostTokens = [
        "analytics", "crashlytics", "firebase", "facebook", "appsflyer",
        "sentry", "amplitude", "adjust", "google-analytics", "doubleclick",
    ]

    private static let shortPathTokens: Set<String> = ["adjust", "sentry"]

    private static let healthSegments: Set<String> = [
        "health", "ready", "live", "ping", "metrics", "favicon", "favicon.ico",
    ]

    private static let imageExts = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".svg"]

    public static func isNoise(_ log: NetworkLog) -> Bool {
        let host = log.hostLabel.lowercased()
        let path = log.pathOnly.lowercased()
        if hostTokens.contains(where: { host.contains($0) }) { return true }
        if pathHasAnalytics(path) { return true }
        if isHealthPath(path) { return true }
        if isImagePath(path) { return true }
        return false
    }

    private static func pathHasAnalytics(_ path: String) -> Bool {
        let segments = path.split(separator: "/").map { raw -> String in
            let s = String(raw)
            if let dot = s.firstIndex(of: ".") { return String(s[..<dot]).lowercased() }
            return s.lowercased()
        }
        for token in hostTokens {
            if shortPathTokens.contains(token) {
                if segments.contains(token) { return true }
                continue
            }
            if path.contains(token) { return true }
        }
        return false
    }

    private static func isHealthPath(_ path: String) -> Bool {
        if path.isEmpty { return false }
        let trimmed = path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
        let last = trimmed.split(separator: "/").last.map(String.init)?.lowercased() ?? trimmed
        if healthSegments.contains(last) { return true }
        if last.hasPrefix("favicon") { return true }
        return healthSegments.contains(where: { trimmed == "/\($0)" || trimmed.hasSuffix("/\($0)") })
    }

    private static func isImagePath(_ path: String) -> Bool {
        let cut = path.split(separator: "?").first.map(String.init) ?? path
        return imageExts.contains { cut.hasSuffix($0) }
    }
}
