import Foundation

public enum DeviceScope: Equatable, Sendable {
    case all
    case usb(ConnectedDevice)

    public var title: String {
        switch self {
        case .all: return "Barcha qurilmalar"
        case .usb(let device): return device.title
        }
    }

    /// Saqlangan serial hozir ulangan qurilmalar ichida bo'lsa shu qurilma, aks holda hammasi.
    public static func resolved(usbSerial: String?, devices: [ConnectedDevice]) -> (scope: DeviceScope, usbSerial: String?) {
        if let serial = usbSerial, let device = devices.first(where: { $0.serial == serial }) {
            return (.usb(device), serial)
        }
        return (.all, nil)
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

    public static func matchesDevice(_ log: NetworkLog, scope: DeviceScope) -> Bool {
        switch scope {
        case .all:
            return true
        case .usb(let device):
            if let serial = log.serial, !serial.isEmpty {
                return serial == device.serial
            }
            return false
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
        if hit(log.queryString.removingPercentEncoding) { return true }
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
        if log.requestHeadersPacked.contains(q) { return true }
        if log.responseHeadersPacked.contains(q) { return true }
        if log.requestBodyPacked.contains(q) { return true }
        if log.responseBodyPacked.contains(q) { return true }
        return false
    }

    public static func matchesSmartQuery(_ log: NetworkLog, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let tokens = trimmed.split(separator: " ").map(String.init)
        for token in tokens {
            if token.hasPrefix("status:") || token.hasPrefix("code:") {
                let val = token.dropFirst(token.hasPrefix("status:") ? 7 : 5)
                if val.hasSuffix("xx") {
                    let prefix = val.prefix(1)
                    let codePrefix = log.responseCode.map { String($0).prefix(1) } ?? ""
                    if codePrefix != prefix { return false }
                } else if let code = Int(val) {
                    if log.responseCode != code { return false }
                }
            } else if token.hasPrefix("method:") || token.hasPrefix("m:") {
                let val = token.dropFirst(token.hasPrefix("method:") ? 7 : 2)
                if log.method.caseInsensitiveCompare(String(val)) != .orderedSame { return false }
            } else if token.hasPrefix("host:") {
                let val = String(token.dropFirst(5))
                if !log.hostLabel.localizedCaseInsensitiveContains(val) { return false }
            } else if token.hasPrefix("path:") {
                let val = String(token.dropFirst(5))
                if !log.pathOnly.localizedCaseInsensitiveContains(val) { return false }
            } else {
                if !matchesQuery(log, query: token) { return false }
            }
        }
        return true
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
            if favoritesOnly && !favoriteKeys.contains(FavoriteKey.hash(log.key)) { return false }
            return true
        }
        .sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
    }

    public static var errorClasses: [StatusClass] {
        [.err4xx, .err5xx, .net]
    }
}

/// Sevimlilar diskda kalit bilan emas, kalitning xeshi bilan saqlanadi — kalit ichida
/// to'liq URL (query'dagi token bilan) bor, u UserDefaults plist'iga tushmasin.
public enum FavoriteKey {
    public static let maxStored = 500

    public static func hash(_ key: String) -> String {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x0000_0100_0000_01b3
        }
        return String(h, radix: 16)
    }

    /// Saqlash chegarasi: avval jonli ro'yxatda yo'q eski xeshlar tashlanadi.
    public static func prune(_ hashes: Set<String>, live: Set<String>) -> Set<String> {
        guard hashes.count > maxStored else { return hashes }
        let kept = hashes.intersection(live)
        if kept.count >= maxStored { return kept }
        let stale = hashes.subtracting(live).sorted()
        return kept.union(stale.prefix(maxStored - kept.count))
    }
}
