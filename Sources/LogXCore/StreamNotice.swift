import Foundation

/// Server `event: error` bilan yuboradigan xom `adb`/`logcat` stderr matnini
/// bitta qatorli tushunarli xabarga aylantiradi. Xom matn ko'p qatorli ingliz
/// stack bo'lishi mumkin (`logcat: Unexpected EOF!\n\nThis means that…`) —
/// bannerga shu holicha chiqsa foydalanuvchi nima qilishni bilmaydi.
public struct StreamNotice: Equatable, Sendable {
    public enum Severity: Sendable, Equatable {
        /// Oqim o'zi tiklanadi — foydalanuvchidan hech narsa talab qilinmaydi.
        case transient
        /// Foydalanuvchi aralashuvi kerak (kabel, ruxsat).
        case actionable
    }

    public let text: String
    public let severity: Severity

    public init(text: String, severity: Severity) {
        self.text = text
        self.severity = severity
    }
}

public enum StreamNoticeParser: Sendable {
    /// Bannerdagi matn shuncha belgidan oshmaydi — noma'lum xato ham bir qatorga sig'adi.
    public static let maxLength = 120

    /// `nil` = ko'rsatilmaydigan shovqin (adb daemon yozuvlari, logcat bo'lim ajratkichi).
    public static func notice(for raw: String) -> StreamNotice? {
        let line = normalize(raw)
        guard !line.isEmpty, !isNoise(line) else { return nil }
        let lower = line.lowercased()

        for rule in rules where rule.matches.contains(where: { lower.contains($0) }) {
            return StreamNotice(text: rule.text, severity: rule.severity)
        }
        return StreamNotice(text: truncate(line), severity: .transient)
    }

    private struct Rule {
        let matches: [String]
        let text: String
        let severity: StreamNotice.Severity
    }

    private static let rules: [Rule] = [
        Rule(
            matches: ["unexpected eof", "as quickly as they were", "unable to read log"],
            text: "Log oqimi uzildi (bufer to'lib ketdi) — qayta ulanyapti",
            severity: .transient
        ),
        Rule(
            matches: ["device unauthorized", "device still authorizing", "unauthorized"],
            text: "Qurilma tasdiqlanmagan — telefonda «Allow USB debugging» ni bosing",
            severity: .actionable
        ),
        Rule(
            matches: ["device offline"],
            text: "Qurilma oflayn — kabelni qayta uling",
            severity: .actionable
        ),
        Rule(
            matches: ["device not found", "no devices/emulators found", "device '"],
            text: "Qurilma topilmadi — USB kabelni tekshiring",
            severity: .actionable
        ),
        Rule(
            matches: ["permission denied"],
            text: "logcat uchun ruxsat yo'q — adb ni qayta ishga tushiring",
            severity: .actionable
        ),
        Rule(
            matches: ["pid map"],
            text: "Ilova xaritasi yangilanmadi — loglar «Noma'lum» ko'rinishi mumkin",
            severity: .transient
        ),
        Rule(
            matches: ["broken pipe", "connection reset", "closed by remote", "killed by signal"],
            text: "Oqim uzildi — qayta ulanyapti",
            severity: .transient
        ),
        Rule(
            matches: ["cannot connect to daemon", "daemon not running", "protocol fault"],
            text: "adb bilan aloqa yo'q — qayta ulanyapti",
            severity: .transient
        ),
    ]

    private static let noiseMarkers = [
        "* daemon not running",
        "* daemon started successfully",
        "--------- beginning of",
        "warning: linker",
    ]

    private static func isNoise(_ line: String) -> Bool {
        let lower = line.lowercased()
        return noiseMarkers.contains { lower.hasPrefix($0) }
    }

    /// Xom matn JSON (`{"message": …}`) bo'lishi, `\n` ni literal ikki belgi
    /// sifatida olib yurishi va ko'p qatorli bo'lishi mumkin — hammasi bitta qatorga.
    private static func normalize(_ raw: String) -> String {
        var text = unwrapMessage(raw)
        text = text.replacingOccurrences(of: "\\n", with: " ")
        text = text.replacingOccurrences(of: "\\t", with: " ")
        let parts = text.split(whereSeparator: { $0.isNewline || $0 == "\t" })
        text = parts.joined(separator: " ")
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        return words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unwrapMessage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else { return trimmed }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return trimmed }
        if let message = object["message"] as? String { return message }
        if let message = object["error"] as? String { return message }
        return trimmed
    }

    private static func truncate(_ line: String) -> String {
        guard line.count > maxLength else { return line }
        let head = line.prefix(maxLength)
        guard let cut = head.lastIndex(where: { $0 == " " }), cut > head.startIndex else {
            return head + "…"
        }
        return head[head.startIndex..<cut] + "…"
    }
}
