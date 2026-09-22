import Foundation

/// So'rov tanalari RAM ning asosiy iste'molchisi: 2500 ta log × bir necha yuz KB
public enum BodyBudget: Sendable {
    public static let maxBodyBytes = 512 * 1024
    public static let totalBodyBytes = 8 * 1024 * 1024

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
        if out.requestBodyPacked.byteCount > limit {
            out.requestBody = clamp(out.requestBody, limit: limit)
        }
        if out.responseBodyPacked.byteCount > limit {
            out.responseBody = clamp(out.responseBody, limit: limit)
        }
        return out
    }

    public static func bytes(_ log: NetworkLog) -> Int {
        payloadBytes(log.requestBodyPacked) + payloadBytes(log.responseBodyPacked)
    }

    private static func payloadBytes(_ packed: PackedText) -> Int {
        isDropped(packed) ? 0 : packed.storedBytes
    }

    public static func isDropped(_ body: String?) -> Bool {
        body == droppedNotice
    }

    public static func isDropped(_ packed: PackedText) -> Bool {
        packed.byteCount == droppedNotice.utf8.count && packed.text == droppedNotice
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
        if !out.requestBodyPacked.isEmpty { out.requestBody = droppedNotice }
        if !out.responseBodyPacked.isEmpty { out.responseBody = droppedNotice }
        return out
    }
}

extension BodyBudget {
    public static let secondaryBodyBytes = 2 * 1024 * 1024

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
