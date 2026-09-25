import Foundation

struct NetworkLogMeta: Equatable, Sendable {
    var feature: String?
    var source: String?
    var appVersion: String?
    var moduleId: String?
    var moduleName: String?
    var environment: String?
    var flavor: String?
    var buildType: String?
    var sessionId: String?
    var userInfoPinfl: String?
    var assistantJshshir: String?
    var responseBodyMessage: String?
    var photoCount: Int?
}

final class NetworkLogMetaBox: Equatable, Sendable {
    static let empty = NetworkLogMetaBox(NetworkLogMeta())

    let value: NetworkLogMeta

    init(_ value: NetworkLogMeta) {
        self.value = value
    }

    static func make(_ value: NetworkLogMeta) -> NetworkLogMetaBox {
        value == empty.value ? empty : NetworkLogMetaBox(value)
    }

    static func == (lhs: NetworkLogMetaBox, rhs: NetworkLogMetaBox) -> Bool {
        lhs === rhs || lhs.value == rhs.value
    }
}

extension NetworkLog {
    private func meta<T>(_ path: KeyPath<NetworkLogMeta, T>) -> T {
        metaBox.value[keyPath: path]
    }

    private mutating func setMeta<T>(_ path: WritableKeyPath<NetworkLogMeta, T>, _ newValue: T) {
        var next = metaBox.value
        next[keyPath: path] = newValue
        metaBox = NetworkLogMetaBox.make(next)
    }

    public var feature: String? {
        get { meta(\.feature) }
        set { setMeta(\.feature, newValue) }
    }
    public var source: String? {
        get { meta(\.source) }
        set { setMeta(\.source, newValue) }
    }
    public var appVersion: String? {
        get { meta(\.appVersion) }
        set { setMeta(\.appVersion, newValue) }
    }
    public var moduleId: String? {
        get { meta(\.moduleId) }
        set { setMeta(\.moduleId, newValue) }
    }
    public var moduleName: String? {
        get { meta(\.moduleName) }
        set { setMeta(\.moduleName, newValue) }
    }
    public var environment: String? {
        get { meta(\.environment) }
        set { setMeta(\.environment, newValue) }
    }
    public var flavor: String? {
        get { meta(\.flavor) }
        set { setMeta(\.flavor, newValue) }
    }
    public var buildType: String? {
        get { meta(\.buildType) }
        set { setMeta(\.buildType, newValue) }
    }
    public var sessionId: String? {
        get { meta(\.sessionId) }
        set { setMeta(\.sessionId, newValue) }
    }
    public var userInfoPinfl: String? {
        get { meta(\.userInfoPinfl) }
        set { setMeta(\.userInfoPinfl, newValue) }
    }
    public var assistantJshshir: String? {
        get { meta(\.assistantJshshir) }
        set { setMeta(\.assistantJshshir, newValue) }
    }
    public var responseBodyMessage: String? {
        get { meta(\.responseBodyMessage) }
        set { setMeta(\.responseBodyMessage, newValue) }
    }
    public var photoCount: Int? {
        get { meta(\.photoCount) }
        set { setMeta(\.photoCount, newValue) }
    }
}
