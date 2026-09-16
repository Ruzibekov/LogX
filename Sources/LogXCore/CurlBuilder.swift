import Foundation

/// NetworkLog'dan ijroga tayyor curl buyrug'ini yig'adi.
public enum CurlBuilder {
    /// curl o'zi hisoblaydigan yoki replay'da zarar keltiradigan sarlavhalar.
    public static let droppedHeaders: Set<String> = [
        "content-length", "accept-encoding", "host", "connection", "transfer-encoding",
    ]

    public static func command(for log: NetworkLog, redact: Bool = false) -> String {
        let rawURL = log.url.isEmpty ? log.api : log.url
        guard !rawURL.isEmpty else { return "" }
        let url = redact ? Redactor.maskURL(rawURL) : rawURL
        var first = "curl"
        let method = log.method.uppercased()
        if method != "GET", method != "?" {
            first += " -X \(method)"
        }
        first += " " + squote(url)
        var parts = [first]
        let headers = redact ? Redactor.mask(log.requestHeaders) : log.requestHeaders
        if wantsCompression(log.requestHeaders) {
            parts.append("--compressed")
        }
        for key in headers.keys.sorted() {
            guard let value = headers[key], !value.isEmpty else { continue }
            guard !droppedHeaders.contains(key.lowercased()) else { continue }
            parts.append("-H " + squote("\(key): \(value)"))
        }
        let body = redact ? Redactor.redactBody(log.requestBody) : log.requestBody
        if let body, !body.isEmpty, !isOmittedBody(body) {
            parts.append("--data-binary " + squote(body))
        }
        return parts.joined(separator: " \\\n  ")
    }

    private static func wantsCompression(_ headers: [String: String]) -> Bool {
        for (key, value) in headers where key.lowercased() == "accept-encoding" {
            let v = value.lowercased()
            return v.contains("gzip") || v.contains("br") || v.contains("deflate")
        }
        return false
    }

    /// OkHttp logger tanani yozmasa `(binary 812-byte body omitted)` kabi izoh qoldiradi —
    /// bu tana emas, uni yuborish mumkin emas.
    public static func isOmittedBody(_ body: String) -> Bool {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("(") && t.hasSuffix(")") && t.lowercased().contains("body omitted")
    }

    /// Bourne-qobiq uchun bittalik qavs ichiga olish; ichidagi qavs '\' maneuveri bilan.
    static func squote(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
