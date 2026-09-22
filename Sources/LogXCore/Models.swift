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
    /// 4xx, 5xx va tarmoq xatosi — «keyingi xato» sakrashi shular ustida yuradi.
    public var isFailure: Bool {
        switch self {
        case .err4xx, .err5xx, .net: return true
        default: return false
        }
    }

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
    public var url: String { didSet { reparseURL() } }
    public var api: String { didSet { reparseURL() } }
    /// URL bir marta ajratiladi (host / yo'l / query) — ro'yxat, filtr va shovqin
    /// tekshiruvi har chaqiruvda qayta parse qilmaydi.
    public private(set) var hostLabel: String = ""
    public private(set) var pathOnly: String = ""
    public private(set) var queryString: String = ""
    public private(set) var resolvedAppId: String = AppProfile.unknownId
    public private(set) var isNoise: Bool = false
    public var responseCode: Int?
    public var responseMessage: String?
    public var durationMs: Int?
    public var error: String?
    public var feature: String?
    public var packageName: String? { didSet { refreshIdentity() } }
    public var source: String?
    public var appId: String? { didSet { refreshIdentity() } }
    public var serial: String?
    public var device: String?
    public var deviceModel: String?
    public var deviceName: String?
    public var appVersion: String?
    public var ts: Double?
    public var requestHeadersPacked: PackedHeaders
    public var responseHeadersPacked: PackedHeaders
    public var requestBodyPacked: PackedText
    public var responseBodyPacked: PackedText
    public var requestHeaders: [String: String] {
        get { requestHeadersPacked.map }
        set { requestHeadersPacked = PackedHeaders(newValue) }
    }
    public var responseHeaders: [String: String] {
        get { responseHeadersPacked.map }
        set { responseHeadersPacked = PackedHeaders(newValue) }
    }
    public var requestBody: String? {
        get { requestBodyPacked.text }
        set { requestBodyPacked = PackedText(newValue) }
    }
    public var responseBody: String? {
        get { responseBodyPacked.text }
        set { responseBodyPacked = PackedText(newValue) }
    }
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
        if code >= 100 && code < 300 { return .ok2xx }
        return .net
    }

    private static func computeAppId(url: String, appId: String?, packageName: String?) -> String {
        if let appId, AppProfile.builtIn.contains(where: { $0.id == appId }) { return appId }
        if let fromPkg = AppProfile.id(forPackage: packageName) { return fromPkg }
        let rawApp = (appId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawApp.isEmpty { return AppProfile.resolveId(rawApp) }
        let pkg = (packageName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !pkg.isEmpty { return pkg }
        let lowerUrl = url.lowercased()
        if lowerUrl.contains("online-mahalla.uz") || lowerUrl.contains("cdn1-mobile.online-mahalla.uz") {
            return "mahalla"
        }
        if lowerUrl.contains("onlineijara.uz") { return "ijara" }
        if lowerUrl.contains("cleanarea.uz") { return "clean_area" }
        if lowerUrl.contains("avtopark") { return "avto_park" }
        return AppProfile.unknownId
    }

    public var appLabel: String { AppProfile.display(for: self).label }
    public var appShortLabel: String { AppProfile.display(for: self).shortLabel }

    public var pathLabel: String {
        queryString.isEmpty ? pathOnly : "\(pathOnly)?\(queryString)"
    }

    private mutating func reparseURL() {
        let parts = URLParts.parse(url.isEmpty ? api : url)
        let pool = StringPool.shared
        hostLabel = pool.intern(parts.host)
        pathOnly = pool.intern(parts.path)
        queryString = parts.query
        isNoise = LogNoise.isNoise(host: hostLabel, path: pathOnly)
        refreshIdentity()
    }

    private mutating func refreshIdentity() {
        resolvedAppId = StringPool.shared.intern(
            NetworkLog.computeAppId(url: url, appId: appId, packageName: packageName)
        )
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
        let pool = StringPool.shared
        self.key = key
        self.method = pool.intern(method.uppercased())
        self.url = url
        self.api = (api == url) ? self.url : api
        self.responseCode = responseCode
        self.responseMessage = responseMessage
        self.durationMs = durationMs
        self.error = error
        self.feature = pool.intern(feature)
        self.packageName = pool.intern(packageName)
        self.source = pool.intern(source)
        self.appId = pool.intern(appId)
        self.serial = pool.intern(serial)
        self.device = pool.intern(device)
        self.deviceModel = pool.intern(deviceModel)
        self.deviceName = pool.intern(deviceName)
        self.appVersion = pool.intern(appVersion)
        self.ts = ts
        self.requestHeadersPacked = PackedHeaders(requestHeaders)
        self.responseHeadersPacked = PackedHeaders(responseHeaders)
        self.requestBodyPacked = PackedText(requestBody)
        self.responseBodyPacked = PackedText(responseBody)
        self.isFull = isFull
        self.moduleId = pool.intern(moduleId)
        self.moduleName = pool.intern(moduleName)
        self.environment = pool.intern(environment)
        self.flavor = pool.intern(flavor)
        self.buildType = pool.intern(buildType)
        self.sessionId = pool.intern(sessionId)
        self.userInfoPinfl = userInfoPinfl
        self.assistantJshshir = assistantJshshir
        self.responseBodyMessage = responseBodyMessage
        self.photoCount = photoCount
        reparseURL()
    }
}

/// Bayt hajmi yorlig'i — ro'yxat, sarlavha va eksport bir xil yozadi.
public enum ByteSize {
    public static func label(_ bytes: Int) -> String {
        if bytes >= 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return "\(bytes) B"
    }
}

/// URL'ni host / yo'l / query ga ajratadi; `URL(string:)` yiqilsa (bo'sh joy,
/// noto'g'ri belgilar) qo'lda bo'linadi — hech qachon butun URL yo'l bo'lib qolmaydi.
public enum URLParts {
    public static func parse(_ raw: String) -> (host: String, path: String, query: String) {
        guard !raw.isEmpty else { return ("", "", "") }
        if let parsed = URL(string: raw), let host = parsed.host {
            let path = parsed.path.isEmpty ? "/" : parsed.path
            return (host, path, parsed.query ?? "")
        }
        var rest = Substring(raw)
        if let hash = rest.firstIndex(of: "#") { rest = rest[..<hash] }
        var query = ""
        if let q = rest.firstIndex(of: "?") {
            query = String(rest[rest.index(after: q)...])
            rest = rest[..<q]
        }
        var host = ""
        if let scheme = rest.range(of: "://") {
            let afterScheme = rest[scheme.upperBound...]
            if let slash = afterScheme.firstIndex(of: "/") {
                host = String(afterScheme[..<slash])
                rest = afterScheme[slash...]
            } else {
                host = String(afterScheme)
                rest = "/"
            }
        }
        return (host, String(rest), query)
    }
}

