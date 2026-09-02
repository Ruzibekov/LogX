import Foundation

public enum SessionExport {
    public static func json(logs: [NetworkLog], redact: Bool) -> Data {
        let items: [[String: Any]] = logs.map { item(for: $0, redact: redact) }
        let root: [String: Any] = [
            "exportedAt": isoNow(),
            "redacted": redact,
            "count": logs.count,
            "items": items,
        ]
        return encode(root)
    }

    public static func har(logs: [NetworkLog], redact: Bool) -> Data {
        let entries: [[String: Any]] = logs.map { harEntry(for: $0, redact: redact) }
        let root: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": [
                    "name": "LogX",
                    "version": "1.0",
                ],
                "entries": entries,
            ] as [String: Any],
        ]
        return encode(root)
    }

    private static func item(for log: NetworkLog, redact: Bool) -> [String: Any] {
        let rawURL = log.url.isEmpty ? log.api : log.url
        var out: [String: Any] = [
            "key": log.key,
            "method": log.method,
            "url": redact ? Redactor.maskURL(rawURL) : rawURL,
            "api": redact ? Redactor.maskURL(log.api) : log.api,
            "host": log.hostLabel,
            "path": log.pathOnly,
        ]
        if let code = log.responseCode { out["status"] = code }
        if let ms = log.durationMs { out["durationMs"] = ms }
        if let ts = log.ts { out["ts"] = ts }
        if let err = log.error, !err.isEmpty { out["error"] = err }
        if let pkg = log.packageName, !pkg.isEmpty { out["packageName"] = pkg }
        if let serial = log.serial, !serial.isEmpty { out["serial"] = serial }
        let reqH = redact ? Redactor.mask(log.requestHeaders) : log.requestHeaders
        let resH = redact ? Redactor.mask(log.responseHeaders) : log.responseHeaders
        if !reqH.isEmpty { out["requestHeaders"] = reqH }
        if !resH.isEmpty { out["responseHeaders"] = resH }
        if let body = log.requestBody, !body.isEmpty {
            out["requestBody"] = redact ? (Redactor.redactBody(body) ?? body) : body
        }
        if let body = log.responseBody, !body.isEmpty {
            out["responseBody"] = redact ? (Redactor.redactBody(body) ?? body) : body
        }
        return out
    }

    private static func harEntry(for log: NetworkLog, redact: Bool) -> [String: Any] {
        let rawURL = log.url.isEmpty ? log.api : log.url
        let url = redact ? Redactor.maskURL(rawURL) : rawURL
        let query = redact ? Redactor.maskParams(log.queryParams) : log.queryParams
        let reqHeaders = redact ? Redactor.mask(log.requestHeaders) : log.requestHeaders
        let resHeaders = redact ? Redactor.mask(log.responseHeaders) : log.responseHeaders
        let reqBody = redact ? Redactor.redactBody(log.requestBody) : log.requestBody
        let resBody = redact ? Redactor.redactBody(log.responseBody) : log.responseBody
        let duration = log.durationMs ?? 0
        var request: [String: Any] = [
            "method": log.method,
            "url": url,
            "httpVersion": "HTTP/1.1",
            "cookies": [] as [Any],
            "headers": harHeaders(reqHeaders),
            "queryString": harQuery(query),
            "headersSize": -1,
            "bodySize": reqBody?.utf8.count ?? 0,
        ]
        if let reqBody, !reqBody.isEmpty {
            request["postData"] = [
                "mimeType": mime(reqHeaders) ?? guessMime(reqBody),
                "text": reqBody,
            ] as [String: Any]
        }
        let response: [String: Any] = [
            "status": log.responseCode ?? 0,
            "statusText": log.statusDescription,
            "httpVersion": "HTTP/1.1",
            "cookies": [] as [Any],
            "headers": harHeaders(resHeaders),
            "content": [
                "size": resBody?.utf8.count ?? 0,
                "mimeType": mime(resHeaders) ?? guessMime(resBody),
                "text": resBody ?? "",
            ] as [String: Any],
            "redirectURL": "",
            "headersSize": -1,
            "bodySize": resBody?.utf8.count ?? 0,
        ]
        return [
            "startedDateTime": isoDate(ts: log.ts),
            "time": duration,
            "request": request,
            "response": response,
            "cache": [:] as [String: Any],
            "timings": [
                "send": 0,
                "wait": duration,
                "receive": 0,
            ] as [String: Any],
        ]
    }

    private static func harHeaders(_ map: [String: String]) -> [[String: String]] {
        map.keys.sorted().map { ["name": $0, "value": map[$0] ?? ""] }
    }

    private static func harQuery(_ params: [(key: String, value: String)]) -> [[String: String]] {
        params.map { ["name": $0.key, "value": $0.value] }
    }

    private static func mime(_ headers: [String: String]) -> String? {
        for (key, value) in headers where key.lowercased() == "content-type" {
            let cut = value.split(separator: ";").first.map(String.init)?.trimmingCharacters(in: .whitespaces)
            if let cut, !cut.isEmpty { return cut }
        }
        return nil
    }

    static func guessMime(_ body: String?) -> String {
        let t = (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]")) {
            return "application/json"
        }
        return "text/plain"
    }

    private static func isoNow() -> String {
        isoFormatter.string(from: Date())
    }

    private static func isoDate(ts: Double?) -> String {
        guard let ts else { return isoNow() }
        let seconds = ts > 10_000_000_000 ? ts / 1000 : ts
        return isoFormatter.string(from: Date(timeIntervalSince1970: seconds))
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func encode(_ obj: Any) -> Data {
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: options) {
            return data
        }
        return Data("{}".utf8)
    }
}
