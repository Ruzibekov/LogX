import Foundation
import LogXCore

extension LogStore {
    func statusCount(_ item: StatusClass) -> Int {
        cachedStatusCounts[item] ?? 0
    }

    var errorCount: Int {
        cachedErrorCount
    }

    var liveApps: [(app: AppProfile, count: Int)] {
        cachedLiveApps
    }

    /// Joriy qurilma+ilova doirasidagi so'rovlar soni (filtrlardan oldin).
    var scopedLogCount: Int { cachedScopedCount }

    /// Shovqin filtri yashirgan so'rovlar soni (joriy doirada).
    var noiseHiddenCount: Int { cachedNoiseHiddenCount }

    /// Hozir ro'yxatda mavjud sevimlilar soni — eski sessiya kalitlari sanalmaydi.
    var liveFavoriteCount: Int { cachedLiveFavoriteCount }

    func isStreamLive(serial: String) -> Bool {
        streamHealthBySerial[serial]?.isLive == true
    }

    var hasLiveStream: Bool {
        streamHealthBySerial.values.contains(where: \.isLive)
    }

    var uniqueHosts: [String] { cachedUniqueHosts }

    /// Ro'yxatdagi hamma so'rov bitta ilovaniki bo'lsa, har qatorda ilova yorlig'i
    /// takrorlanmaydi — u hech narsani ajratmaydi.
    var hasMultipleLiveApps: Bool { cachedLiveApps.count > 1 }

    /// Bitta xost bo'lsa uni har qatorda takrorlash shovqin — yo'lning o'zi yetadi.
    var hasMultipleHosts: Bool { cachedUniqueHosts.count > 1 }

    func repeatCount(for log: NetworkLog) -> Int {
        cachedEndpointCounts[EndpointIdentity.key(for: log)] ?? 1
    }

    var hasActiveFilter: Bool {
        selectedAppId != "all"
            || status != .all
            || favoritesOnly
            || errorsOnly
            || selectedMethod != "ALL"
            || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || slowOnly
            || !(selectedHost ?? "").isEmpty
    }

    var pendingWhilePausedCount: Int { pendingWhilePaused.count }

    /// Log xotira sig'imiga yaqin — eng eskilari tushib ketadi.
    var isNearCapacity: Bool { liveByKey.count >= maxLogCapacity * 9 / 10 }

    /// Tanlangan so'rov — filtr uni yashirgan bo'lsa ham qaytadi (`selectedIsHidden` bilan).
    var selectedLog: NetworkLog? {
        guard let selectedKey else { return nil }
        return liveByKey[selectedKey]
    }

    /// Nusxalash/ko'rsatish uchun URL — «Tokenlar» yoqiq bo'lsa query'dagi sezgir qiymatlar yashirin.
    func shareableURL(_ log: NetworkLog) -> String {
        let raw = log.url.isEmpty ? log.api : log.url
        return redactEnabled ? Redactor.maskURL(raw) : raw
    }

    /// Ro'yxatdagi yo'l (`/path?query`) — redakt yoqiq bo'lsa query qiymatlari yashirin.
    func displayPath(_ log: NetworkLog) -> String {
        redactEnabled ? Redactor.maskURL(log.pathLabel) : log.pathLabel
    }
}
