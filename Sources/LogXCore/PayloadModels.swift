import Foundation

public struct DevicesPayload: Decodable {
    public var ok: Bool?
    public var error: String?
    public var devices: [ConnectedDevice]
    public var adbConflict: AdbConflict?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        devices = try c.decodeIfPresent([ConnectedDevice].self, forKey: .devices) ?? []
        adbConflict = try? c.decodeIfPresent(AdbConflict.self, forKey: .adbConflict)
    }

    enum CodingKeys: String, CodingKey { case ok, error, devices, adbConflict }
}

public struct AppsPayload: Decodable {
    public var ok: Bool?
    public var apps: [AppProfile]
}

public struct LogEnvelope: Decodable {
    public var key: String
    public var value: LogValue
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
    public var _pending: Bool?
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
            isPending: _pending == true,
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
