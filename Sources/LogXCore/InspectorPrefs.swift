import Foundation

public struct InspectorPrefs: Codable, Equatable, Sendable {
    public var hideNoise: Bool
    public var followLatest: Bool
    public var slowOnly: Bool
    public var selectedMethod: String
    public var status: String
    public var errorsOnly: Bool
    public var selectedAppId: String
    public var selectedSerial: String?

    public static let storageKey = "logx.inspector"

    public static let `default` = InspectorPrefs(
        hideNoise: true,
        followLatest: false,
        slowOnly: false,
        selectedMethod: "ALL",
        status: StatusClass.all.rawValue,
        errorsOnly: false,
        selectedAppId: "all",
        selectedSerial: nil
    )

    public init(
        hideNoise: Bool = true,
        followLatest: Bool = false,
        slowOnly: Bool = false,
        selectedMethod: String = "ALL",
        status: String = "all",
        errorsOnly: Bool = false,
        selectedAppId: String = "all",
        selectedSerial: String? = nil
    ) {
        self.hideNoise = hideNoise
        self.followLatest = followLatest
        self.slowOnly = slowOnly
        self.selectedMethod = selectedMethod.isEmpty ? "ALL" : selectedMethod
        self.status = status.isEmpty ? StatusClass.all.rawValue : status
        self.errorsOnly = errorsOnly
        self.selectedAppId = selectedAppId.isEmpty ? "all" : selectedAppId
        self.selectedSerial = selectedSerial?.isEmpty == true ? nil : selectedSerial
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hideNoise = try c.decodeIfPresent(Bool.self, forKey: .hideNoise) ?? true
        followLatest = try c.decodeIfPresent(Bool.self, forKey: .followLatest) ?? false
        slowOnly = try c.decodeIfPresent(Bool.self, forKey: .slowOnly) ?? false
        let method = try c.decodeIfPresent(String.self, forKey: .selectedMethod) ?? "ALL"
        selectedMethod = method.isEmpty ? "ALL" : method
        let rawStatus = try c.decodeIfPresent(String.self, forKey: .status) ?? StatusClass.all.rawValue
        status = rawStatus.isEmpty ? StatusClass.all.rawValue : rawStatus
        errorsOnly = try c.decodeIfPresent(Bool.self, forKey: .errorsOnly) ?? false
        let app = try c.decodeIfPresent(String.self, forKey: .selectedAppId) ?? "all"
        selectedAppId = app.isEmpty ? "all" : app
        let serial = try c.decodeIfPresent(String.self, forKey: .selectedSerial)
        selectedSerial = (serial?.isEmpty == false) ? serial : nil
    }

    public static func load(defaults: UserDefaults = .standard) -> InspectorPrefs {
        guard let data = defaults.data(forKey: storageKey) else { return .default }
        do {
            return try JSONDecoder().decode(InspectorPrefs.self, from: data)
        } catch {
            return .default
        }
    }

    public func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

public enum FollowLatest {
    public static func selectedKey(
        batch: [NetworkLog],
        currentKey: String?,
        follow: Bool,
        paused: Bool
    ) -> String? {
        if paused { return currentKey }
        let local = batch.filter { LogFilter.isLocal($0) }
        if follow {
            var best: NetworkLog?
            for log in local {
                if let cur = best {
                    if (log.ts ?? 0) >= (cur.ts ?? 0) { best = log }
                } else {
                    best = log
                }
            }
            return best?.key ?? currentKey
        }
        if currentKey == nil {
            return local.first?.key
        }
        return currentKey
    }
}
