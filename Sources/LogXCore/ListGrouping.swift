import Foundation

public enum ListRow: Identifiable, Equatable, Sendable {
    case host(name: String, count: Int)
    case log(NetworkLog)

    public var id: String {
        switch self {
        case let .host(name, _): return "host:\(name)"
        case let .log(log): return log.key
        }
    }
}

public enum ListGrouping: Sendable {
    public static func rows(_ logs: [NetworkLog]) -> [ListRow] {
        guard !logs.isEmpty else { return [] }
        var out: [ListRow] = []
        var runStart = 0
        var headerIndex = -1
        var current = ""
        for (index, log) in logs.enumerated() {
            let host = log.hostLabel
            if index == runStart, headerIndex < 0 {
                current = host
                if !host.isEmpty {
                    headerIndex = out.count
                    out.append(.host(name: host, count: 0))
                }
            } else if host != current {
                if headerIndex >= 0 {
                    out[headerIndex] = .host(name: current, count: index - runStart)
                }
                runStart = index
                current = host
                headerIndex = host.isEmpty ? -1 : out.count
                if !host.isEmpty { out.append(.host(name: host, count: 0)) }
            }
            out.append(.log(log))
        }
        if headerIndex >= 0 {
            out[headerIndex] = .host(name: current, count: logs.count - runStart)
        }
        return out
    }
}
