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
        if log.method.range(of: q, options: .caseInsensitive) != nil { return true }
        if log.url.range(of: q, options: .caseInsensitive) != nil { return true }
        if log.api.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.packageName, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.device, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.deviceModel, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.error, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.responseMessage, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.responseBodyMessage, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.feature, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.moduleName, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.sessionId, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let v = log.userInfoPinfl, v.range(of: q, options: .caseInsensitive) != nil { return true }
        if let code = log.responseCode, String(code).range(of: q, options: .caseInsensitive) != nil { return true }
        if log.appLabel.range(of: q, options: .caseInsensitive) != nil { return true }
        if log.appShortLabel.range(of: q, options: .caseInsensitive) != nil { return true }
        return false
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
        errorsOnly: Bool = false
    ) -> [NetworkLog] {
        logs.filter { log in
            guard isLocal(log),
                  matchesApp(log, appId: appId),
                  matchesDevice(log, scope: scope) else { return false }
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

    public static var errorClasses: [StatusClass] {
        [.err4xx, .err5xx, .net]
    }
}
