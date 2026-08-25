import Foundation

public struct ConnectedDevice: Identifiable, Equatable, Sendable, Codable {
    public var serial: String
    public var model: String
    public var product: String
    public var preferred: Bool

    public var id: String { serial }

    public var title: String {
        let name = model.isEmpty ? (product.isEmpty ? "Qurilma" : product) : model.replacingOccurrences(of: "_", with: " ")
        return name
    }

    public init(serial: String, model: String = "", product: String = "", preferred: Bool = false) {
        self.serial = serial
        self.model = model
        self.product = product
        self.preferred = preferred
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serial = try c.decode(String.self, forKey: .serial)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        product = try c.decodeIfPresent(String.self, forKey: .product) ?? ""
        preferred = try c.decodeIfPresent(Bool.self, forKey: .preferred) ?? false
    }
}

public enum StatusClass: String, Equatable, Sendable, CaseIterable {
    case all
    case ok2xx
    case redirect3xx
    case err4xx
    case err5xx
    case net

    public var title: String {
        switch self {
        case .all: return "Barchasi"
        case .ok2xx: return "2xx"
        case .redirect3xx: return "3xx"
        case .err4xx: return "4xx"
        case .err5xx: return "5xx"
        case .net: return "NET"
        }
    }
}

public struct NetworkLog: Identifiable, Equatable, Sendable {
    public var key: String
    public var method: String
    public var url: String
    public var api: String
    public var responseCode: Int?
    public var responseMessage: String?
    public var durationMs: Int?
    public var error: String?
    public var feature: String?
    public var packageName: String?
    public var source: String?
    public var appId: String?
    public var serial: String?
    public var device: String?
    public var deviceModel: String?
    public var deviceName: String?
    public var appVersion: String?
    public var ts: Double?
    public var requestHeaders: [String: String]
    public var responseHeaders: [String: String]
    public var requestBody: String?
    public var responseBody: String?
    public var isFull: Bool
    public var moduleId: String?
    public var moduleName: String?
    public var environment: String?
    public var flavor: String?
    public var buildType: String?
    public var sessionId: String?
    public var userInfoPinfl: String?
    public var assistantJshshir: String?
    public var responseBodyMessage: String?
    public var photoCount: Int?

    public var id: String { key }

    public var statusClass: StatusClass {
        guard let code = responseCode else { return .net }
        if code >= 500 { return .err5xx }
        if code >= 400 { return .err4xx }
        if code >= 300 && code < 400 { return .redirect3xx }
        if code >= 200 && code < 300 { return .ok2xx }
        return .net
    }

    public var resolvedAppId: String {
        if let appId, AppProfile.builtIn.contains(where: { $0.id == appId }) { return appId }
        if let fromPkg = AppProfile.id(forPackage: packageName) { return fromPkg }
        let rawApp = (appId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawApp.isEmpty { return AppProfile.resolveId(rawApp) }
        let pkg = (packageName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !pkg.isEmpty { return pkg }
        return AppProfile.unknownId
    }

    public var appLabel: String { AppProfile.display(for: self).label }
    public var appShortLabel: String { AppProfile.display(for: self).shortLabel }

    public var pathLabel: String {
        let raw = url.isEmpty ? api : url
        guard let parsed = URL(string: raw) else { return raw }
        let path = parsed.path.isEmpty ? raw : parsed.path
        if let q = parsed.query, !q.isEmpty { return "\(path)?\(q)" }
        return path
    }

    public var statusDescription: String {
        if let msg = responseMessage, !msg.isEmpty { return msg }
        guard let code = responseCode else { return error ?? "Network Error" }
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 408: return "Request Timeout"
        case 409: return "Conflict"
        case 422: return "Unprocessable Entity"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        default: return "HTTP \(code)"
        }
    }

    public var queryParams: [(key: String, value: String)] {
        let raw = url.isEmpty ? api : url
        guard let components = URLComponents(string: raw),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else { return [] }
        return queryItems.map { ($0.name, $0.value ?? "") }
    }

    public var formattedDuration: String {
        guard let ms = durationMs else { return "—" }
        if ms >= 1000 { return String(format: "%.2f s", Double(ms) / 1000) }
        return "\(ms) ms"
    }

    public var formattedBodySize: String {
        let bytes = (responseBody?.utf8.count ?? 0)
        guard bytes > 0 else { return "—" }
        if bytes >= 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return "\(bytes) B"
    }

    public init(
        key: String,
        method: String = "?",
        url: String = "",
        api: String = "",
        responseCode: Int? = nil,
        responseMessage: String? = nil,
        durationMs: Int? = nil,
        error: String? = nil,
        feature: String? = nil,
        packageName: String? = nil,
        source: String? = nil,
        appId: String? = nil,
        serial: String? = nil,
        device: String? = nil,
        deviceModel: String? = nil,
        deviceName: String? = nil,
        appVersion: String? = nil,
        ts: Double? = nil,
        requestHeaders: [String: String] = [:],
        responseHeaders: [String: String] = [:],
        requestBody: String? = nil,
        responseBody: String? = nil,
        isFull: Bool = false,
        moduleId: String? = nil,
        moduleName: String? = nil,
        environment: String? = nil,
        flavor: String? = nil,
        buildType: String? = nil,
        sessionId: String? = nil,
        userInfoPinfl: String? = nil,
        assistantJshshir: String? = nil,
        responseBodyMessage: String? = nil,
        photoCount: Int? = nil
    ) {
        self.key = key
        self.method = method
        self.url = url
        self.api = api
        self.responseCode = responseCode
        self.responseMessage = responseMessage
        self.durationMs = durationMs
        self.error = error
        self.feature = feature
        self.packageName = packageName
        self.source = source
        self.appId = appId
        self.serial = serial
        self.device = device
        self.deviceModel = deviceModel
        self.deviceName = deviceName
        self.appVersion = appVersion
        self.ts = ts
        self.requestHeaders = requestHeaders
        self.responseHeaders = responseHeaders
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.isFull = isFull
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.environment = environment
        self.flavor = flavor
        self.buildType = buildType
        self.sessionId = sessionId
        self.userInfoPinfl = userInfoPinfl
        self.assistantJshshir = assistantJshshir
        self.responseBodyMessage = responseBodyMessage
        self.photoCount = photoCount
    }
}

public struct DevicesPayload: Decodable {
    public var ok: Bool?
    public var error: String?
    public var devices: [ConnectedDevice]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        devices = try c.decodeIfPresent([ConnectedDevice].self, forKey: .devices) ?? []
    }

    enum CodingKeys: String, CodingKey { case ok, error, devices }
}

public struct AppsPayload: Decodable {
    public var ok: Bool?
    public var apps: [AppProfile]
}

public struct LogsPayload: Decodable {
    public var ok: Bool?
    public var error: String?
    public var items: [LogEnvelope]

    public init(ok: Bool? = true, error: String? = nil, items: [LogEnvelope] = []) {
        self.ok = ok
        self.error = error
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        items = try c.decodeIfPresent([LogEnvelope].self, forKey: .items) ?? []
    }

    enum CodingKeys: String, CodingKey { case ok, error, items }
}

public struct LogEnvelope: Decodable {
    public var key: String
    public var value: LogValue
}

public struct LogDetailPayload: Decodable {
    public var ok: Bool?
    public var item: LogEnvelope?
}

public struct LogValue: Decodable {
    public var method: String?
    public var url: String?
    public var api: String?
    public var responseCode: Int?
    public var responseMessage: String?
    public var durationMs: Int?
    public var error: String?
    public var feature: String?
    public var packageName: String?
    public var source: String?
    public var appId: String?
    public var serial: String?
    public var device: String?
    public var deviceModel: String?
    public var deviceName: String?
    public var appVersion: String?
    public var ts: Double?
    public var requestHeaders: LooseMap?
    public var responseHeaders: LooseMap?
    public var requestBody: LooseText?
    public var responseBody: LooseText?
    public var _slim: Bool?
    public var moduleId: String?
    public var moduleName: String?
    public var environment: String?
    public var flavor: String?
    public var buildType: String?
    public var sessionId: String?
    public var userInfoPinfl: String?
    public var assistantJshshir: String?
    public var responseBodyMessage: String?
    public var photoCount: Int?

    public func asLog(key: String) -> NetworkLog {
        NetworkLog(
            key: key,
            method: (method ?? "?").uppercased(),
            url: url ?? "",
            api: api ?? url ?? "",
            responseCode: responseCode,
            responseMessage: responseMessage,
            durationMs: durationMs,
            error: error,
            feature: feature,
            packageName: packageName,
            source: source,
            appId: appId,
            serial: serial,
            device: device,
            deviceModel: deviceModel,
            deviceName: deviceName,
            appVersion: appVersion,
            ts: ts,
            requestHeaders: requestHeaders?.values ?? [:],
            responseHeaders: responseHeaders?.values ?? [:],
            requestBody: requestBody?.text,
            responseBody: responseBody?.text,
            isFull: _slim == false,
            moduleId: moduleId,
            moduleName: moduleName,
            environment: environment,
            flavor: flavor,
            buildType: buildType,
            sessionId: sessionId,
            userInfoPinfl: userInfoPinfl,
            assistantJshshir: assistantJshshir,
            responseBodyMessage: responseBodyMessage,
            photoCount: photoCount
        )
    }
}
