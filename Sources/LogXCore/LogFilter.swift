import Foundation

public enum DeviceScope: Equatable, Sendable {
    case all
    case usb(ConnectedDevice)
    case field(FieldDevice)

    public var title: String {
        switch self {
        case .all: return "Barcha qurilmalar"
        case .usb(let device): return device.title
        case .field(let field): return field.label
        }
    }

    public static func resolved(
        usbSerial: String?,
        fieldId: String?,
        devices: [ConnectedDevice],
        fields: [FieldDevice]
    ) -> (scope: DeviceScope, usbSerial: String?, fieldId: String?) {
        if let serial = usbSerial, let device = devices.first(where: { $0.serial == serial }) {
            return (.usb(device), serial, nil)
        }
        if let id = fieldId, let field = fields.first(where: { $0.id == id }) {
            return (.field(field), nil, id)
        }
        return (.all, nil, nil)
    }
}

public struct FieldDevice: Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var count: Int

    public init(id: String, label: String, count: Int) {
        self.id = id
        self.label = label
        self.count = count
    }
}

public enum FieldDevices {
    public static func collect(_ logs: [NetworkLog]) -> [FieldDevice] {
        var map: [String: (label: String, count: Int)] = [:]
        for log in logs {
            let label = log.fieldDeviceLabel
            guard label != "—" else { continue }
            let id = log.fieldDeviceId
            var cur = map[id] ?? (label, 0)
            cur.count += 1
            if cur.label == "—" { cur.label = label }
            map[id] = cur
        }
        return map
            .map { FieldDevice(id: $0.key, label: $0.value.label, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
    }
}

public enum LogFilter {
    public static func isLocal(_ log: NetworkLog) -> Bool {
        let src = (log.source ?? "").lowercased()
        if src.contains("rtdb") || src == "demo" { return false }
        if let serial = log.serial, !serial.isEmpty { return true }
        return src == "logcat" || src == "live" || src == "usb"
    }

    public static func matchesApp(_ log: NetworkLog, appId: String?) -> Bool {
        guard let appId, !appId.isEmpty, appId != "all" else { return true }
        return log.resolvedAppId == AppProfile.resolveId(appId)
    }

    public static func matchesDevice(_ log: NetworkLog, device: ConnectedDevice?) -> Bool {
        matchesDevice(log, scope: device.map { .usb($0) } ?? .all)
    }

    public static func matchesDevice(_ log: NetworkLog, scope: DeviceScope) -> Bool {
        switch scope {
        case .all:
            return true
        case .usb(let device):
            if let serial = log.serial, !serial.isEmpty {
                return serial == device.serial
            }
            return false
        case .field(let field):
            if log.fieldDeviceId == field.id { return true }
            let needle = field.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !needle.isEmpty, needle != "—" else { return false }
            let hay = [log.device, log.deviceModel, log.deviceName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            return hay.contains { $0 == needle || $0.contains(needle) || needle.contains($0) }
        }
    }

    public static func matchesStatus(_ log: NetworkLog, status: StatusClass) -> Bool {
        status == .all || log.statusClass == status
    }

    public static func matchesQuery(_ log: NetworkLog, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        func hit(_ s: String?) -> Bool {
            guard let s, !s.isEmpty else { return false }
            return s.range(of: q, options: .caseInsensitive) != nil
        }
        if hit(log.method) { return true }
        if hit(log.url) { return true }
        if hit(log.api) { return true }
        if hit(log.hostLabel) { return true }
        if hit(log.pathLabel) { return true }
        if hit(log.packageName) { return true }
        if hit(log.device) { return true }
        if hit(log.deviceModel) { return true }
        if hit(log.error) { return true }
        if hit(log.responseMessage) { return true }
        if hit(log.responseBodyMessage) { return true }
        if hit(log.feature) { return true }
        if hit(log.moduleName) { return true }
        if hit(log.sessionId) { return true }
        if hit(log.userInfoPinfl) { return true }
        if let code = log.responseCode, hit(String(code)) { return true }
        if hit(log.appLabel) { return true }
        if hit(log.appShortLabel) { return true }
        if hit(log.requestBody) { return true }
        if hit(log.responseBody) { return true }
        for (key, value) in log.requestHeaders {
            if hit(key) || hit(value) { return true }
        }
        for (key, value) in log.responseHeaders {
            if hit(key) || hit(value) { return true }
        }
        for pair in log.queryParams {
            if hit(pair.key) || hit(pair.value) { return true }
        }
        return false
    }

    public static func matchesMethod(_ log: NetworkLog, method: String) -> Bool {
        let m = method.trimmingCharacters(in: .whitespacesAndNewlines)
        if m.isEmpty || m.uppercased() == "ALL" { return true }
        return log.method.uppercased() == m.uppercased()
    }

    public static func matchesHost(_ log: NetworkLog, host: String?) -> Bool {
        guard let host, !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return log.hostLabel.caseInsensitiveCompare(host) == .orderedSame
    }

    public static func matchesSlow(_ log: NetworkLog, slowOnly: Bool) -> Bool {
        guard slowOnly else { return true }
        guard let ms = log.durationMs else { return false }
        return ms >= LogNoise.slowThresholdMs
    }

    public static func apply(
        _ logs: [NetworkLog],
        appId: String?,
        device: ConnectedDevice?,
        status: StatusClass,
        query: String
    ) -> [NetworkLog] {
        apply(logs, appId: appId, scope: device.map { .usb($0) } ?? .all, status: status, query: query)
    }

    public static func apply(
        _ logs: [NetworkLog],
        appId: String?,
        scope: DeviceScope,
        status: StatusClass,
        query: String,
        favoritesOnly: Bool = false,
        favoriteKeys: Set<String> = [],
        errorsOnly: Bool = false,
        method: String = "ALL",
        hideNoise: Bool = false,
        slowOnly: Bool = false,
        selectedHost: String? = nil
    ) -> [NetworkLog] {
        logs.filter { log in
            guard isLocal(log),
                  matchesApp(log, appId: appId),
                  matchesDevice(log, scope: scope) else { return false }
            if hideNoise && LogNoise.isNoise(log) { return false }
            guard matchesMethod(log, method: method) else { return false }
            guard matchesHost(log, host: selectedHost) else { return false }
            guard matchesSlow(log, slowOnly: slowOnly) else { return false }
            if errorsOnly {
                guard errorClasses.contains(log.statusClass) else { return false }
            } else {
                guard matchesStatus(log, status: status) else { return false }
            }
            guard matchesQuery(log, query: query) else { return false }
            if favoritesOnly && !favoriteKeys.contains(log.key) { return false }
            return true
        }
        .sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
    }

    public static func statusCounts(
        _ logs: [NetworkLog],
        appId: String?,
        scope: DeviceScope,
        query: String,
        favoritesOnly: Bool = false,
        favoriteKeys: Set<String> = [],
        method: String = "ALL",
        hideNoise: Bool = false,
        slowOnly: Bool = false,
        selectedHost: String? = nil
    ) -> [StatusClass: Int] {
        var counts: [StatusClass: Int] = [
            .all: 0, .ok2xx: 0, .redirect3xx: 0, .err4xx: 0, .err5xx: 0, .net: 0,
        ]
        let filtered = apply(
            logs,
            appId: appId,
            scope: scope,
            status: .all,
            query: query,
            favoritesOnly: favoritesOnly,
            favoriteKeys: favoriteKeys,
            errorsOnly: false,
            method: method,
            hideNoise: hideNoise,
            slowOnly: slowOnly,
            selectedHost: selectedHost
        )
        for log in filtered {
            counts[.all, default: 0] += 1
            counts[log.statusClass, default: 0] += 1
        }
        return counts
    }

    public static var errorClasses: [StatusClass] {
        [.err4xx, .err5xx, .net]
    }
}
