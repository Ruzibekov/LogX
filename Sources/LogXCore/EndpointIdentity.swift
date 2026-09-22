import Foundation

public enum EndpointIdentity {
    public static func key(for log: NetworkLog) -> String {
        let method = log.method.uppercased()
        let host = log.hostLabel
        let path = log.pathOnly
        return "\(method) \(host) \(path)"
    }

    public static func hash(for log: NetworkLog) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ text: String, upper: Bool) {
            for byte in text.utf8 {
                let value = upper && byte >= 0x61 && byte <= 0x7A ? byte - 32 : byte
                h ^= UInt64(value)
                h = h &* 0x0000_0100_0000_01b3
            }
            h ^= 0x20
            h = h &* 0x0000_0100_0000_01b3
        }
        mix(log.method, upper: true)
        mix(log.hostLabel, upper: false)
        mix(log.pathOnly, upper: false)
        return h
    }

    public static func counts(in logs: [NetworkLog]) -> [UInt64: Int] {
        var map: [UInt64: Int] = [:]
        for log in logs {
            map[hash(for: log), default: 0] += 1
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
