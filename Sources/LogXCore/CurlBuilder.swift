import Foundation

/// NetworkLog'dan ijroga tayyor curl buyrug'ini yig'adi.
public enum CurlBuilder {
    public static func command(for log: NetworkLog, redact: Bool = false) -> String {
        let url = log.url.isEmpty ? log.api : log.url
        guard !url.isEmpty else { return "" }
        var first = "curl"
        let method = log.method.uppercased()
        if method != "GET", method != "?" {
            first += " -X \(method)"
        }
        first += " " + squote(url)
        var parts = [first]
        let headers = redact ? Redactor.mask(log.requestHeaders) : log.requestHeaders
        for key in headers.keys.sorted() {
            guard let value = headers[key], !value.isEmpty else { continue }
            parts.append("-H " + squote("\(key): \(value)"))
        }
        if let body = log.requestBody, !body.isEmpty {
            parts.append("--data-binary " + squote(body))
        }
        return parts.joined(separator: " \\\n  ")
    }

    /// Bourne-qobiq uchun bittalik qavs ichiga olish; ichidagi qavs '\' maneuveri bilan.
    static func squote(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Ulashiladigan kontentdan sezgir qiymatlarni yashiradi.
public enum Redactor {
    public static let sensitiveKeys: Set<String> = [
        "authorization", "cookie", "set-cookie", "token", "access-token",
        "refresh-token", "api-key", "x-api-key", "x-auth-token", "pinfl", "jshshir",
        "password", "secret", "client-secret", "private-key",
    ]

    public static func isSensitive(_ key: String) -> Bool {
        let k = key.lowercased()
        return sensitiveKeys.contains(k)
            || k.contains("token")
            || k.contains("pinfl")
            || k.contains("jshshir")
            || k.contains("pass")
            || k.contains("secret")
    }

    public static func mask(_ headers: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in headers {
            out[key] = isSensitive(key) ? "••••••" : value
        }
        return out
    }

    public static func maskText(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return text }
        var out = text
        for marker in ["Bearer ", "bearer "] {
            if let range = out.range(of: marker) {
                let tail = String(out[range.upperBound...])
                let token = tail.prefix { !$0.isWhitespace && $0 != "\"" && $0 != "'" && $0 != "," }
                if !token.isEmpty {
                    out = String(out[..<range.upperBound]) + "••••••" + String(tail.dropFirst(token.count))
                }
            }
        }
        return out
    }
}
