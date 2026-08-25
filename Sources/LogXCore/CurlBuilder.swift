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

    public static func maskJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return text
        }
        if let dict = obj as? [String: Any] {
            return stringify(maskJSONValue(dict)) ?? text
        }
        if let arr = obj as? [Any] {
            return stringify(maskJSONValue(arr)) ?? text
        }
        if let s = obj as? String {
            return maskText(s) ?? s
        }
        return text
    }

    public static func redactBody(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return text }
        let jsonMasked = maskJSON(text)
        return maskText(jsonMasked) ?? jsonMasked
    }

    private static func maskJSONValue(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (key, nested) in dict {
                if isSensitive(key) {
                    out[key] = "••••••"
                } else {
                    out[key] = maskJSONValue(nested)
                }
            }
            return out
        }
        if let arr = value as? [Any] {
            return arr.map { maskJSONValue($0) }
        }
        if let s = value as? String {
            return maskText(s) ?? s
        }
        return value
    }

    private static func stringify(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
