import Foundation

public enum SignalLevel: String, Equatable, Sendable {
    case unmeasured
    case normal
    case slow
    case verySlow
}

public struct SignalPoint: Equatable, Identifiable, Sendable {
    public let key: String
    public let x: Double
    public let y: Double
    public let durationMs: Double?
    public let level: SignalLevel
    public let statusClass: StatusClass

    public var id: String { key }

    public init(key: String, x: Double, y: Double, durationMs: Double?, level: SignalLevel, statusClass: StatusClass) {
        self.key = key
        self.x = x
        self.y = y
        self.durationMs = durationMs
        self.level = level
        self.statusClass = statusClass
    }
}

public enum SignalTrace {
    public static let baselineY = 0.06
    public static let headroom = 2.5
    public static let referenceFloorMs = 40.0

    public static func level(_ durationMs: Double?) -> SignalLevel {
        guard let ms = durationMs, ms > 0 else { return .unmeasured }
        if ms >= Double(LogNoise.verySlowThresholdMs) { return .verySlow }
        if ms >= Double(LogNoise.slowThresholdMs) { return .slow }
        return .normal
    }

    public static func reference(_ durations: [Double]) -> Double {
        let typical = LatencySummary.percentile(durations, 0.75) ?? 0
        return max(typical * headroom, referenceFloorMs)
    }

    public static func step(limit: Int) -> Double {
        limit > 1 ? 1 / Double(limit - 1) : 0
    }

    public static func points(_ logs: [NetworkLog], limit: Int = LatencySummary.defaultLimit) -> [SignalPoint] {
        guard limit > 0 else { return [] }
        let window = Array(logs.prefix(limit).reversed())
        guard !window.isEmpty else { return [] }
        let durations = window.compactMap(\.durationMs).map(Double.init).filter { $0 > 0 }
        let ref = reference(durations)
        let dx = step(limit: limit)
        let last = window.count - 1
        return window.enumerated().map { index, log in
            let ms = log.durationMs.map(Double.init)
            let x = limit > 1 ? 1 - Double(last - index) * dx : 1
            return SignalPoint(
                key: log.key,
                x: x,
                y: amplitude(ms, reference: ref),
                durationMs: ms,
                level: level(ms),
                statusClass: log.statusClass
            )
        }
    }

    public static func amplitude(_ durationMs: Double?, reference: Double) -> Double {
        guard let ms = durationMs, ms > 0, reference > 0 else { return baselineY }
        let span = 1 - baselineY
        return min(1, baselineY + span * (ms / reference))
    }

    public static func nearest(_ points: [SignalPoint], toX x: Double) -> SignalPoint? {
        points.min { abs($0.x - x) < abs($1.x - x) }
    }
}
