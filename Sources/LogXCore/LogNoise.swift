import Foundation

public enum LogNoise {
    public static let slowThresholdMs = 800
    public static let verySlowThresholdMs = 3000

    private static let hostTokens = [
        "analytics", "crashlytics", "firebase", "facebook", "appsflyer",
        "sentry", "amplitude", "adjust", "google-analytics", "doubleclick",
    ]

    /// Yo'l segmenti aynan shu so'z bo'lsagina shovqin — `/report/analytics`
    /// kabi biznes endpoint substring bilan yashirilmaydi.
    private static let pathTokens: Set<String> = [
        "analytics", "crashlytics", "appsflyer", "sentry", "amplitude", "adjust",
    ]

    private static let healthSegments: Set<String> = [
        "health", "healthz", "healthcheck", "ready", "readyz", "ping", "liveness", "readiness",
    ]

    private static let imageExts = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".svg"]

    public static func isNoise(_ log: NetworkLog) -> Bool {
        log.isNoise
    }

    public static func isNoise(host rawHost: String, path rawPath: String) -> Bool {
        let host = rawHost.lowercased()
        let path = rawPath.lowercased()
        if hostIsNoise(host) { return true }
        if pathHasAnalytics(path) { return true }
        if isHealthPath(path) { return true }
        if isImagePath(path) { return true }
        return false
    }

    /// Host yorlig'i token bilan to'liq mos yoki uzun token uchun prefiks
    /// (`firebaseinstallations.googleapis.com`); qisqa token faqat aynan
    /// (`adjustments.example.uz` — `adjust` emas).
    private static func hostIsNoise(_ host: String) -> Bool {
        let labels = host.split(separator: ".").map(String.init)
        return labels.contains { label in
            hostTokens.contains { token in
                label == token || (token.count >= 8 && label.hasPrefix(token))
            }
        }
    }

    private static func segments(_ path: String) -> [String] {
        path.split(separator: "/").map { raw -> String in
            let s = String(raw)
            if let dot = s.firstIndex(of: ".") { return String(s[..<dot]) }
            return s
        }
    }

    private static func pathHasAnalytics(_ path: String) -> Bool {
        segments(path).contains(where: { pathTokens.contains($0) })
    }

    private static let healthPrefixes: Set<String> = ["api", "actuator", "internal", "v1", "v2"]

    /// Sog'liq yo'li ildizda (`/health`) yoki bitta texnik prefiks ostida (`/api/health`);
    /// `/v1/orders/ready` biznes so'rovi — shovqin emas.
    private static func isHealthPath(_ path: String) -> Bool {
        let parts = path.split(separator: "/").map(String.init)
        guard let last = parts.last else { return false }
        if last.hasPrefix("favicon") { return true }
        guard healthSegments.contains(last) else { return false }
        if parts.count == 1 { return true }
        return parts.count == 2 && healthPrefixes.contains(parts[0])
    }

    private static func isImagePath(_ path: String) -> Bool {
        imageExts.contains { path.hasSuffix($0) }
    }
}
