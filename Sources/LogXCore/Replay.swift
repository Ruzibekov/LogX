import Foundation

public struct ReplayResult: Equatable, Sendable {
    public var statusCode: Int?
    public var statusMessage: String?
    public var headers: [String: String]
    public var body: String?
    public var durationMs: Int
    public var error: String?

    public init(statusCode: Int? = nil, statusMessage: String? = nil, headers: [String: String] = [:], body: String? = nil, durationMs: Int = 0, error: String? = nil) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
        self.body = body
        self.durationMs = durationMs
        self.error = error
    }
}

/// Yozib olingan so'rovni Mac'dan qayta yuboradi va javobni ro'yxatga
/// yangi yozuv sifatida qaytaradi. Sarlavhalar cURL bilan bir xil qoidada:
/// transport hisoblaydiganlari tashlanadi, token/cookie asl holicha ketadi.
public enum Replay {
    public static let sourceTag = "replay"
    public static let keyPrefix = "replay:"
    public static let timeout: TimeInterval = 30
    public static let maxBodyBytes = 4 * 1024 * 1024

    public enum BuildError: Error, Equatable {
        case emptyURL
        case invalidURL(String)
        case omittedBody
    }

    /// POST/PATCH/DELETE serverda o'zgarish qiladi — qayta yuborishdan oldin tasdiq so'raladi.
    public static func isMutating(_ method: String) -> Bool {
        ["POST", "PATCH", "DELETE"].contains(method.uppercased())
    }

    public static func isReplay(_ log: NetworkLog) -> Bool {
        (log.source ?? "").lowercased() == sourceTag || log.key.hasPrefix(keyPrefix)
    }

    public static func request(for log: NetworkLog) throws -> URLRequest {
        let raw = log.url.isEmpty ? log.api : log.url
        guard !raw.isEmpty else { throw BuildError.emptyURL }
        guard let url = URL(string: raw), url.host != nil else { throw BuildError.invalidURL(raw) }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        let method = log.method.uppercased()
        req.httpMethod = (method == "?" || method.isEmpty) ? "GET" : method
        for key in log.requestHeaders.keys.sorted() {
            guard let value = log.requestHeaders[key], !value.isEmpty else { continue }
            guard !CurlBuilder.droppedHeaders.contains(key.lowercased()) else { continue }
            req.setValue(value, forHTTPHeaderField: key)
        }
        if let body = log.requestBody, !body.isEmpty {
            if CurlBuilder.isOmittedBody(body) { throw BuildError.omittedBody }
            req.httpBody = body.data(using: .utf8)
        }
        return req
    }

    public static func request(method: String, url: URL, headers: [String: String], body: String?) throws -> URLRequest {
        guard url.host != nil else { throw BuildError.invalidURL(url.absoluteString) }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        let m = method.uppercased()
        req.httpMethod = (m == "?" || m.isEmpty) ? "GET" : m
        for key in headers.keys.sorted() {
            guard let value = headers[key], !value.isEmpty else { continue }
            guard !CurlBuilder.droppedHeaders.contains(key.lowercased()) else { continue }
            req.setValue(value, forHTTPHeaderField: key)
        }
        if let body, !body.isEmpty {
            if CurlBuilder.isOmittedBody(body) { throw BuildError.omittedBody }
            req.httpBody = body.data(using: .utf8)
        }
        return req
    }

    public static func perform(_ log: NetworkLog, session: URLSession = Replay.session) async -> ReplayResult {
        let req: URLRequest
        do {
            req = try request(for: log)
        } catch {
            return ReplayResult(error: describe(error))
        }
        return await execute(req, session: session)
    }

    public static func performCustom(method: String, url: URL, headers: [String: String], body: String?, session: URLSession = Replay.session) async -> ReplayResult {
        let req: URLRequest
        do {
            req = try request(method: method, url: url, headers: headers, body: body)
        } catch {
            return ReplayResult(error: describe(error))
        }
        return await execute(req, session: session)
    }

    private static func execute(_ req: URLRequest, session: URLSession) async -> ReplayResult {
        let started = Date()
        do {
            let (data, response) = try await session.data(for: req)
            let elapsed = Int(Date().timeIntervalSince(started) * 1000)
            let http = response as? HTTPURLResponse
            var headers: [String: String] = [:]
            for (k, v) in http?.allHeaderFields ?? [:] {
                headers[String(describing: k)] = String(describing: v)
            }
            return ReplayResult(
                statusCode: http?.statusCode,
                statusMessage: http.map { HTTPURLResponse.localizedString(forStatusCode: $0.statusCode).capitalized },
                headers: headers,
                body: bodyText(data),
                durationMs: elapsed
            )
        } catch {
            let elapsed = Int(Date().timeIntervalSince(started) * 1000)
            return ReplayResult(durationMs: elapsed, error: describe(error))
        }
    }

    public static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static func bodyText(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if data.count > maxBodyBytes {
            return "(javob tanasi \(ByteSize.label(data.count)) — \(ByteSize.label(maxBodyBytes)) dan katta, ko'rsatilmaydi)"
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        return "(binary \(data.count)-byte body)"
    }

    public static func describe(_ error: Error) -> String {
        if let build = error as? BuildError {
            switch build {
            case .emptyURL: return "URL bo'sh — qayta yuborib bo'lmaydi"
            case .invalidURL(let raw): return "URL yaroqsiz: \(raw)"
            case .omittedBody: return "Tana yozib olinmagan (body omitted) — qayta yuborib bo'lmaydi"
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorTimedOut: return "Vaqt tugadi (\(Int(timeout)) s)"
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed: return "Host topilmadi"
            case NSURLErrorCannotConnectToHost: return "Hostga ulanib bo'lmadi"
            case NSURLErrorNotConnectedToInternet: return "Internet yo'q"
            case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted: return "TLS xatosi"
            default: break
            }
        }
        return ns.localizedDescription
    }

    /// Natija ro'yxatdagi yozuvga aylanadi: asl qurilma/ilova saqlanadi, manba `replay`.
    public static func log(from result: ReplayResult, original: NetworkLog, key: String, ts: Double) -> NetworkLog {
        var sentHeaders: [String: String] = [:]
        for (k, v) in original.requestHeaders where !CurlBuilder.droppedHeaders.contains(k.lowercased()) && !v.isEmpty {
            sentHeaders[k] = v
        }
        return NetworkLog(
            key: key,
            method: original.method,
            url: original.url,
            api: original.api,
            responseCode: result.statusCode,
            responseMessage: result.statusMessage,
            durationMs: result.durationMs,
            error: result.error,
            feature: original.feature,
            packageName: original.packageName,
            source: sourceTag,
            appId: original.appId,
            serial: original.serial,
            device: original.device,
            deviceModel: original.deviceModel,
            deviceName: original.deviceName,
            appVersion: original.appVersion,
            ts: ts,
            requestHeaders: sentHeaders,
            responseHeaders: result.headers,
            requestBody: original.requestBody,
            responseBody: result.body,
            isFull: true,
            moduleId: original.moduleId,
            moduleName: original.moduleName,
            environment: original.environment,
            flavor: original.flavor,
            buildType: original.buildType,
            sessionId: original.sessionId
        )
    }

    public static func log(from result: ReplayResult, original: NetworkLog, key: String, ts: Double, method: String, url: String, requestHeaders: [String: String], requestBody: String?) -> NetworkLog {
        var sentHeaders: [String: String] = [:]
        for (k, v) in requestHeaders where !CurlBuilder.droppedHeaders.contains(k.lowercased()) && !v.isEmpty {
            sentHeaders[k] = v
        }
        return NetworkLog(
            key: key,
            method: method,
            url: url,
            api: url,
            responseCode: result.statusCode,
            responseMessage: result.statusMessage,
            durationMs: result.durationMs,
            error: result.error,
            feature: original.feature,
            packageName: original.packageName,
            source: sourceTag,
            appId: original.appId,
            serial: original.serial,
            device: original.device,
            deviceModel: original.deviceModel,
            deviceName: original.deviceName,
            appVersion: original.appVersion,
            ts: ts,
            requestHeaders: sentHeaders,
            responseHeaders: result.headers,
            requestBody: requestBody,
            responseBody: result.body,
            isFull: true,
            moduleId: original.moduleId,
            moduleName: original.moduleName,
            environment: original.environment,
            flavor: original.flavor,
            buildType: original.buildType,
            sessionId: original.sessionId
        )
    }
}
