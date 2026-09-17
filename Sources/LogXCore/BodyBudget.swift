import Foundation

/// So'rov tanalari RAM ning asosiy iste'molchisi: 2500 ta log × bir necha yuz KB
/// osonlik bilan gigabaytga chiqadi. Shuning uchun tana kirishda chegaralanadi va
/// umumiy byudjetdan oshganda eng eski loglarning tanasi tashlanadi — metama qoladi.
public enum BodyBudget: Sendable {
    /// Bitta tana uchun yuqori chegara.
    public static let maxBodyBytes = 512 * 1024
    /// Barcha saqlanadigan tanalar uchun byudjet.
    public static let totalBodyBytes = 32 * 1024 * 1024

    public static let truncatedNotice = "\n… LogX: tana chegaradan katta, qolgani kesildi"
    public static let droppedNotice = "… LogX: xotira byudjeti — eski so'rov tanasi tashlandi"

    /// Tanani `maxBodyBytes` gacha qisqartiradi; UTF-8 belgisi o'rtasidan kesilmaydi.
    public static func clamp(_ body: String?, limit: Int = maxBodyBytes) -> String? {
        guard let body, body.utf8.count > limit else { return body }
        var bytes = Array(body.utf8.prefix(limit))
        while !bytes.isEmpty, String(bytes: bytes, encoding: .utf8) == nil {
            bytes.removeLast()
        }
        let head = String(bytes: bytes, encoding: .utf8) ?? ""
        return head + truncatedNotice
    }

    public static func clamp(_ log: NetworkLog, limit: Int = maxBodyBytes) -> NetworkLog {
        var out = log
        out.requestBody = clamp(log.requestBody, limit: limit)
        out.responseBody = clamp(log.responseBody, limit: limit)
        return out
    }

    /// Bitta logning tanalari egallagan bayt.
    public static func bytes(_ log: NetworkLog) -> Int {
        payloadBytes(log.requestBody) + payloadBytes(log.responseBody)
    }

    private static func payloadBytes(_ body: String?) -> Int {
        guard let body, body != droppedNotice else { return 0 }
        return body.utf8.count
    }

    public static func isDropped(_ body: String?) -> Bool {
        body == droppedNotice
    }

    /// Tanasi tashlanadigan kalitlar. `sizes` yangidan eskiga tartiblangan bo'lishi kerak:
    /// byudjet to'lgach undan keyingi (eskiroq) yozuvlar tashlanadi. `protected` hech qachon tegilmaydi.
    public static func keysToDrop(
        sizes: [(key: String, bytes: Int)],
        budget: Int = totalBodyBytes,
        protected: Set<String> = []
    ) -> [String] {
        var used = 0
        var drop: [String] = []
        for entry in sizes {
            if entry.bytes == 0 { continue }
            if protected.contains(entry.key) {
                used += entry.bytes
                continue
            }
            if used + entry.bytes <= budget {
                used += entry.bytes
            } else {
                drop.append(entry.key)
            }
        }
        return drop
    }

    /// Tanani belgili matn bilan almashtiradi — foydalanuvchi nima uchun yo'qligini ko'radi.
    public static func dropBodies(_ log: NetworkLog) -> NetworkLog {
        var out = log
        if out.requestBody != nil { out.requestBody = droppedNotice }
        if out.responseBody != nil { out.responseBody = droppedNotice }
        return out
    }
}

extension BodyBudget {
    public static let secondaryBodyBytes = 8 * 1024 * 1024

    public static func enforce(newestFirst logs: [NetworkLog], budget: Int = secondaryBodyBytes) -> [NetworkLog] {
        var used = 0
        var out = logs
        for index in out.indices {
            let size = bytes(out[index])
            if size == 0 { continue }
            if used + size <= budget {
                used += size
            } else {
                out[index] = dropBodies(out[index])
            }
        }
        return out
    }

    public static func totalBytes(_ logs: some Sequence<NetworkLog>) -> Int {
        logs.reduce(0) { $0 + bytes($1) }
    }
}
