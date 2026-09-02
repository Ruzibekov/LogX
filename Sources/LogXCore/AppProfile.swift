import Foundation

public struct AppProfile: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var label: String
    public var shortLabel: String
    public var pkg: String
    public var networkSource: String

    public init(
        id: String,
        label: String,
        shortLabel: String,
        pkg: String,
        networkSource: String = "logcat"
    ) {
        self.id = id
        self.label = label
        self.shortLabel = shortLabel
        self.pkg = pkg
        self.networkSource = networkSource
    }

    public static let unknownId = "unknown"

    public static let unknown = AppProfile(
        id: unknownId,
        label: "Noma'lum",
        shortLabel: "Noma'lum",
        pkg: "",
        networkSource: "logcat"
    )

    public static let builtIn: [AppProfile] = [
        AppProfile(
            id: "mahalla",
            label: "Online Mahalla",
            shortLabel: "Mahalla",
            pkg: "uz.realsoft.onlinemahalla.assistant",
            networkSource: "rtdb"
        ),
        AppProfile(
            id: "ijara",
            label: "Online Ijara",
            shortLabel: "Ijara",
            pkg: "uz.realsoft.onlineijara",
            networkSource: "logcat"
        ),
        AppProfile(
            id: "clean_area",
            label: "Toza Hudud",
            shortLabel: "Toza Hudud",
            pkg: "realsoft.cleanarea.uz",
            networkSource: "logcat"
        ),
        AppProfile(
            id: "avto_park",
            label: "Avto-park",
            shortLabel: "Avto-park",
            pkg: "uz.realsoft.bukhara.avtopark",
            networkSource: "logcat"
        ),
        AppProfile(
            id: "rsiddemo",
            label: "RS ID Demo",
            shortLabel: "RS ID Demo",
            pkg: "uz.realsoft.rsid.demo",
            networkSource: "rtdb-demo"
        ),
    ]

    public static func resolveId(_ raw: String?) -> String {
        let id = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if id.isEmpty { return unknownId }
        if builtIn.contains(where: { $0.id == id }) { return id }
        switch id {
        case "online_ijara", "online-ijara", "onlineijara": return "ijara"
        case "clean-area", "cleanarea", "toza", "tozahudud", "toza_hudud", "toza-hudud":
            return "clean_area"
        case "rsid", "rs-id", "demo", "rsid-demo", "rs-id-demo": return "rsiddemo"
        case "online_mahalla", "online-mahalla", "assistant": return "mahalla"
        case "avto-park", "avtopark", "avto_park", "bukhara", "bukhara-avtopark", "bukhara_avtopark":
            return "avto_park"
        default: return id
        }
    }

    public static func id(forPackage pkg: String?) -> String? {
        let needle = (pkg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        return builtIn.first(where: { $0.pkg == needle })?.id
    }

    public static func discovered(id: String, packageName: String?) -> AppProfile {
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let pkg = (packageName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedId == unknownId || (trimmedId.isEmpty && pkg.isEmpty) { return unknown }
        let seed = pkg.isEmpty ? trimmedId : packageSeed(pkg)
        let short = humanize(seed)
        return AppProfile(
            id: trimmedId.isEmpty ? pkg : trimmedId,
            label: short,
            shortLabel: short,
            pkg: pkg,
            networkSource: "logcat"
        )
    }

    public static func display(for log: NetworkLog) -> AppProfile {
        let id = log.resolvedAppId
        if let hit = builtIn.first(where: { $0.id == id }) { return hit }
        if id == unknownId { return unknown }
        return discovered(id: id, packageName: log.packageName)
    }

    public static func merge(api: [AppProfile], logs: [NetworkLog]) -> [AppProfile] {
        var byId: [String: AppProfile] = [:]
        for profile in builtIn { byId[profile.id] = profile }
        for profile in api where !profile.id.isEmpty { byId[profile.id] = profile }
        for log in logs {
            let id = log.resolvedAppId
            if byId[id] == nil {
                byId[id] = display(for: log)
            }
        }
        var seen = Set<String>()
        var out: [AppProfile] = []
        for profile in builtIn {
            if let hit = byId[profile.id], seen.insert(hit.id).inserted {
                out.append(hit)
            }
        }
        let rest = byId.values
            .filter { !seen.contains($0.id) }
            .sorted {
                $0.shortLabel.localizedCaseInsensitiveCompare($1.shortLabel) == .orderedAscending
            }
        out.append(contentsOf: rest)
        return out
    }

    /// Paketning oxirgi segmenti umumiy so'z bo'lsa (`…myapp.android`) oldingisi olinadi.
    static let genericSegments: Set<String> = ["app", "android", "mobile", "client", "debug", "release", "dev", "prod", "staging"]

    static func packageSeed(_ pkg: String) -> String {
        let parts = pkg.split(separator: ".").map(String.init)
        guard let last = parts.last else { return pkg }
        if parts.count >= 2, genericSegments.contains(last.lowercased()) {
            return parts[parts.count - 2]
        }
        return last
    }

    public static func humanize(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.first else { return unknown.shortLabel }
        return String(first).uppercased() + cleaned.dropFirst()
    }
}
