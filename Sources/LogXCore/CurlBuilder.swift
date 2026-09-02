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

/// Ulashiladigan kontentdan sezgir qiymatlarni yashiradi.
public enum Redactor {
    public static let placeholder = "••••••"

    /// Kalit so'zlarga bo'linadi (`X-Auth-Token` → x/auth/token, `userPassword` → user/password)
    /// va so'z bo'yicha solishtiriladi — `passenger` yoki `tokenizer` yashirilmaydi.
    public static let sensitiveTokens: Set<String> = [
        "authorization", "auth", "cookie", "token", "pinfl", "jshshir",
        "password", "passwd", "pwd", "pass", "secret", "otp", "jwt", "apikey",
        "session", "sessionid", "cvv", "cvc", "pin", "passport", "credential",
        "credentials", "bearer", "csrf", "xsrf", "refresh", "smscode",
    ]

    static let sensitivePairs: [(String, String)] = [
        ("api", "key"), ("private", "key"), ("access", "key"), ("card", "number"),
        ("client", "secret"), ("sms", "code"), ("secret", "key"), ("signing", "key"),
    ]

    public static func isSensitive(_ key: String) -> Bool {
        let parts = tokens(key)
        if parts.contains(where: { sensitiveTokens.contains($0) }) { return true }
        for i in parts.indices.dropLast() {
            if sensitivePairs.contains(where: { $0.0 == parts[i] && $0.1 == parts[i + 1] }) { return true }
        }
        return false
    }

    static func tokens(_ key: String) -> [String] {
        var out: [String] = []
        var current = ""
        var prevLower = false
        for ch in key {
            if ch.isLetter || ch.isNumber {
                if ch.isUppercase && prevLower {
                    if !current.isEmpty { out.append(current) }
                    current = ""
                }
                current.append(ch.lowercased())
                prevLower = ch.isLowercase
            } else {
                if !current.isEmpty { out.append(current) }
                current = ""
                prevLower = false
            }
        }
        if !current.isEmpty { out.append(current) }
        return out.map(stripTrailingDigits)
    }

    private static func stripTrailingDigits(_ token: String) -> String {
        let trimmed = String(token.reversed().drop(while: { $0.isNumber }).reversed())
        return trimmed.isEmpty ? token : trimmed
    }

    public static func mask(_ headers: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in headers {
            out[key] = isSensitive(key) ? placeholder : (maskText(value) ?? value)
        }
        return out
    }

    private static let jwtRegex = try! NSRegularExpression(
        pattern: #"eyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]*"#
    )

    /// `Bearer …`, `Basic …` va yalang'och JWT tokenlarini yashiradi.
    public static func maskText(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return text }
        var out = maskScheme(text, scheme: "bearer ")
        out = maskScheme(out, scheme: "basic ", tokenFilter: looksLikeBase64)
        let ns = out as NSString
        let matches = jwtRegex.matches(in: out, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return out }
        var result = ""
        var cursor = 0
        for m in matches {
            result += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            result += placeholder
            cursor = m.range.location + m.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }

    /// `Basic` dan keyingi so'z faqat base64 ko'rinishida bo'lsa token — `"plan":"basic monthly"` tegilmaydi.
    private static func looksLikeBase64(_ token: Substring) -> Bool {
        token.count >= 12 && token.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" || $0 == "=" || $0 == "-" || $0 == "_" }
    }

    private static func maskScheme(
        _ text: String,
        scheme: String,
        tokenFilter: (Substring) -> Bool = { _ in true }
    ) -> String {
        var out = ""
        var rest = Substring(text)
        while let range = rest.range(of: scheme, options: [.caseInsensitive]) {
            out += rest[..<range.upperBound]
            let tail = rest[range.upperBound...]
            let token = tail.prefix { !$0.isWhitespace && $0 != "\"" && $0 != "'" && $0 != "," }
            if token.isEmpty || !tokenFilter(token) {
                rest = tail
                continue
            }
            out += placeholder
            rest = tail.dropFirst(token.count)
        }
        out += rest
        return out
    }

    /// Query satridagi sezgir kalitlarning qiymatini yashiradi; boshqa qismi o'zgarmaydi.
    public static func maskURL(_ url: String) -> String {
        guard let q = url.firstIndex(of: "?") else { return url }
        let head = url[...q]
        var tail = url[url.index(after: q)...]
        var fragment: Substring = ""
        if let hash = tail.firstIndex(of: "#") {
            fragment = tail[hash...]
            tail = tail[..<hash]
        }
        return head + maskPairs(String(tail)) + fragment
    }

    /// `a=1&token=x` shaklidagi satr (query yoki form tana).
    static func maskPairs(_ text: String) -> String {
        text.split(separator: "&", omittingEmptySubsequences: false).map { pair -> String in
            guard let eq = pair.firstIndex(of: "=") else { return String(pair) }
            let key = String(pair[..<eq])
            let decoded = key.removingPercentEncoding ?? key
            return isSensitive(decoded) ? key + "=" + placeholder : String(pair)
        }.joined(separator: "&")
    }

    public static func maskParams(_ params: [(key: String, value: String)]) -> [(key: String, value: String)] {
        params.map { isSensitive($0.key) ? (key: $0.key, value: placeholder) : $0 }
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

    private static let rawKeyRegex = try! NSRegularExpression(
        pattern: #""((?:[^"\\]|\\.)*)"\s*:\s*"#
    )

    /// JSON matnini qayta yig'masdan (bo'shliq/tartib saqlanadi) sezgir kalit qiymatini yashiradi.
    /// Qiymat obyekt/massiv bo'lsa butunlay, satr ichida JSON yotsa u ham yashiriladi.
    public static func maskRawJSONText(_ text: String) -> String {
        let ns = text as NSString
        let matches = rawKeyRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }
        var result = ""
        var cursor = 0
        for m in matches {
            let valueStart = m.range.location + m.range.length
            guard valueStart >= cursor, let valueEnd = rawValueEnd(ns, from: valueStart) else { continue }
            let key = ns.substring(with: m.range(at: 1))
            let valueRange = NSRange(location: valueStart, length: valueEnd - valueStart)
            let replacement: String
            if isSensitive(key) {
                replacement = "\"\(placeholder)\""
            } else if ns.character(at: valueStart) == 0x22,
                      let nested = maskRawStringLiteral(ns.substring(with: valueRange)) {
                replacement = nested
            } else {
                continue
            }
            result += ns.substring(with: NSRange(location: cursor, length: valueStart - cursor))
            result += replacement
            cursor = valueEnd
        }
        result += ns.substring(from: cursor)
        return result
    }

    /// `"..."` literal ichida JSON yotsa (`"{\"token\":..}"`) yashirilgan literalni qaytaradi, aks holda nil.
    private static func maskRawStringLiteral(_ literal: String) -> String? {
        guard let data = "[\(literal)]".data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String],
              let inner = arr.first
        else { return nil }
        let t = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]")) else { return nil }
        let masked = maskNestedString(inner)
        guard masked != inner,
              let out = try? JSONSerialization.data(withJSONObject: [masked], options: [.withoutEscapingSlashes]),
              let encoded = String(data: out, encoding: .utf8)
        else { return nil }
        return String(encoded.dropFirst().dropLast())
    }

    /// JSON qiymatining oxirini topadi: satr (escape bilan), balanslangan obyekt/massiv yoki skalyar.
    private static func rawValueEnd(_ ns: NSString, from start: Int) -> Int? {
        let length = ns.length
        guard start < length else { return nil }
        let first = ns.character(at: start)
        if first == 0x22 {
            var i = start + 1
            while i < length {
                let c = ns.character(at: i)
                if c == 0x5C { i += 2; continue }
                if c == 0x22 { return i + 1 }
                i += 1
            }
            return nil
        }
        if first == 0x7B || first == 0x5B {
            var depth = 0
            var inString = false
            var i = start
            while i < length {
                let c = ns.character(at: i)
                if inString {
                    if c == 0x5C { i += 2; continue }
                    if c == 0x22 { inString = false }
                } else if c == 0x22 {
                    inString = true
                } else if c == 0x7B || c == 0x5B {
                    depth += 1
                } else if c == 0x7D || c == 0x5D {
                    depth -= 1
                    if depth == 0 { return i + 1 }
                }
                i += 1
            }
            return nil
        }
        var i = start
        while i < length {
            let c = ns.character(at: i)
            if c == 0x2C || c == 0x7D || c == 0x5D || c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 { break }
            i += 1
        }
        return i > start ? i : nil
    }

    static func looksLikeForm(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.hasPrefix("{"), !t.hasPrefix("["), !t.contains("\n") else { return false }
        let pairs = t.split(separator: "&")
        return !pairs.isEmpty && pairs.allSatisfy { $0.contains("=") }
    }

    /// `preserveFormat` — matn qayta yig'ilmaydi (Raw ko'rinish), faqat qiymat almashadi.
    public static func redactBody(_ text: String?, preserveFormat: Bool = false) -> String? {
        guard let text, !text.isEmpty else { return text }
        if looksLikeForm(text) {
            return maskText(maskPairs(text))
        }
        let jsonMasked = preserveFormat ? maskRawJSONText(text) : maskJSON(text)
        return maskText(jsonMasked) ?? jsonMasked
    }

    private static func maskJSONValue(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (key, nested) in dict {
                if isSensitive(key) {
                    out[key] = placeholder
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
            return maskNestedString(s)
        }
        return value
    }

    /// Satr ichida yana JSON yotsa (`"payload": "{\"token\":..}"`) u ham yashiriladi.
    private static func maskNestedString(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]")),
           let data = t.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data),
           let out = stringify(maskJSONValue(obj)) {
            return out
        }
        return maskText(s) ?? s
    }

    private static func stringify(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
