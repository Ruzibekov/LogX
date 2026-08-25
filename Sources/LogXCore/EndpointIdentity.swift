import Foundation

public enum EndpointIdentity {
    public static func key(for log: NetworkLog) -> String {
        let method = log.method.uppercased()
        let host = log.hostLabel
        let path = log.pathOnly
        return "\(method) \(host) \(path)"
    }

    public static func counts(in logs: [NetworkLog]) -> [String: Int] {
        var map: [String: Int] = [:]
        for log in logs {
            map[key(for: log), default: 0] += 1
        }
        return map
    }

    public static func uniqueHosts(_ logs: [NetworkLog]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for log in logs {
            let host = log.hostLabel
            guard !host.isEmpty, !seen.contains(host) else { continue }
            seen.insert(host)
            out.append(host)
        }
        return out.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
