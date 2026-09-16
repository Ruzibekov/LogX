import Foundation

/// Ro'yxat ustidagi kechikish chizig'i uchun bitta ustun.
public struct LatencyBar: Equatable, Identifiable, Sendable {
    public let key: String
    /// 0…1 — logarifmik shkalada normallashtirilgan balandlik.
    public let ratio: Double
    public let statusClass: StatusClass
    public let durationMs: Double?

    public var id: String { key }

    public init(key: String, ratio: Double, statusClass: StatusClass, durationMs: Double?) {
        self.key = key
        self.ratio = ratio
        self.statusClass = statusClass
        self.durationMs = durationMs
    }
}

/// Kechikish statistikasi — ko'rinadigan so'rovlardan hisoblanadi, hech narsa saqlanmaydi.
public enum LatencySummary {
    /// Eng ko'pi bilan shuncha ustun chiziladi; qolgani chizilmaydi (RAM va chizish narxi).
    public static let defaultLimit = 72

    public static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count == 1 { return sorted[0] }
        let clamped = min(max(p, 0), 1)
        let position = clamped * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        if lower == upper { return sorted[lower] }
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    /// Eng yangisi oxirida turadigan ustunlar. `logs` vaqt bo'yicha kamayuvchi tartibda kutiladi.
    public static func bars(_ logs: [NetworkLog], limit: Int = defaultLimit) -> [LatencyBar] {
        guard limit > 0 else { return [] }
        let window = Array(logs.prefix(limit)).reversed()
        let durations = window.compactMap(\.durationMs).map(Double.init).filter { $0 > 0 }
        let peak = durations.max() ?? 0
        let peakScale = peak > 0 ? log10(peak + 1) : 0
        return window.map { log in
            let ms = log.durationMs.map(Double.init)
            var ratio = 0.06
            if let ms, ms > 0, peakScale > 0 {
                ratio = max(0.06, min(1, log10(ms + 1) / peakScale))
            }
            return LatencyBar(key: log.key, ratio: ratio, statusClass: log.statusClass, durationMs: ms)
        }
    }

    /// Chiziq sarlavhasidagi p95 yozuvi; o'lchov bo'lmasa nil.
    public static func p95Label(_ logs: [NetworkLog], limit: Int = defaultLimit) -> String? {
        let durations = logs.prefix(limit).compactMap(\.durationMs).map(Double.init).filter { $0 > 0 }
        guard let value = percentile(durations, 0.95) else { return nil }
        if value >= 1000 {
            return String(format: "p95 %.2f s", value / 1000)
        }
        return "p95 \(Int(value.rounded())) ms"
    }
}
