import Foundation
import LogXCore

@MainActor
final class LogStore: ObservableObject {
    @Published var devices: [ConnectedDevice] = []
    @Published var apps: [AppProfile] = AppProfile.builtIn
    @Published var selectedSerial: String?
    @Published var selectedAppId: String = "all"
    @Published var status: StatusClass = .all
    @Published var query: String = ""
    @Published var favoritesOnly = false
    /// Sevimlilar kalit xeshi bilan saqlanadi (kalit ichida to'liq URL bor).
    @Published var favoriteKeys: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "logx.favoriteHashes") ?? []
    )
    @Published private(set) var allLogs: [NetworkLog] = []
    @Published var selectedKey: String?
    @Published var detailTab: DetailTab = .response
    @Published var serverOK = false
    @Published var banner: String?
    @Published var isLoading = true
    @Published var isPaused = false
    @Published var selectedMethod: String = "ALL"
    @Published var errorsOnly = false
    @Published var hideNoise = true
    @Published var followLatest = false
    @Published var slowOnly = false
    @Published var selectedHost: String?
    @Published var lastActivityTs: Double?
    /// Pauza paytida kelgan loglar tashlanmaydi — buferda turadi, davom etilganda kiradi.
    @Published var pendingWhilePaused: [NetworkLog] = []
    /// Tanlangan so'rov hozirgi filtr bilan ro'yxatda ko'rinmayapti.
    @Published var selectedIsHidden = false
    /// Qisqa xabar (nusxalandi, tozalandi…) — ixtiyoriy amal tugmasi bilan.
    @Published var toast: Toast?
    var toastTask: Task<Void, Never>?
    /// Pidlar noma'lum bo'lib qolgan streak — server pid xaritasi eskirgan (ilova qayta ochilgan).
    var unknownAppStreak: [String: Int] = [:]
    var lastUnknownReopen: [String: Date] = [:]
    var refreshFailures = 0
    var clearedKeys: Set<String> = []
    var clearedSnapshot: [String: NetworkLog] = [:]
    @Published var connection: AppConnection = .booting
    @Published var streamHealthBySerial: [String: StreamHealth] = [:]
    @Published var redactEnabled = UserDefaults.standard.bool(forKey: "logx.redact") {
        didSet { UserDefaults.standard.set(redactEnabled, forKey: "logx.redact") }
    }

    let maxLogCapacity = 2500
    static let unknownStreakLimit = 5
    static let unknownReopenThrottle: TimeInterval = 30
    static let serverDownAfterFailures = 2
    static let queryDebounce: TimeInterval = 0.12
    static let serverStartRetryInterval: TimeInterval = 30
    var client = MonitorClient()
    var liveTasks: [String: Task<Void, Never>] = [:]
    var pollTask: Task<Void, Never>?
    var queryTask: Task<Void, Never>?
    var startGeneration = 0
    var liveByKey: [String: NetworkLog] = [:]
    var apiApps: [AppProfile] = AppProfile.builtIn
    var lastServerStartAttempt: Date?

    var cachedVisibleLogs: [NetworkLog] = []
    var cachedVisibleKeys: Set<String> = []
    var cachedStatusCounts: [StatusClass: Int] = [:]
    var cachedErrorCount: Int = 0
    var cachedLiveApps: [(app: AppProfile, count: Int)] = []
    var cachedUniqueHosts: [String] = []
    var cachedEndpointCounts: [String: Int] = [:]
    var cachedScopedCount: Int = 0
    var cachedNoiseHiddenCount: Int = 0
    var cachedLiveFavoriteCount: Int = 0
    var queryMatchCache: [String: Bool] = [:]
    var queryMatchCacheFor: String = ""

    init() {
        let prefs = InspectorPrefs.load()
        hideNoise = prefs.hideNoise
        followLatest = prefs.followLatest
        selectedAppId = prefs.selectedAppId
        selectedSerial = prefs.selectedSerial
    }

    var selectedScope: DeviceScope {
        DeviceScope.resolved(usbSerial: selectedSerial, devices: devices).scope
    }

    var visibleLogs: [NetworkLog] {
        cachedVisibleLogs
    }

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

    func togglePause() {
        isPaused.toggle()
        if !isPaused, !pendingWhilePaused.isEmpty {
            let buffered = pendingWhilePaused
            pendingWhilePaused = []
            ingestBatch(buffered)
        }
        publishConnection()
    }

    var pendingWhilePausedCount: Int { pendingWhilePaused.count }

    /// Log xotira sig'imiga yaqin — eng eskilari tushib ketadi.
    var isNearCapacity: Bool { liveByKey.count >= maxLogCapacity * 9 / 10 }

    func toggleErrorsOnly() {
        errorsOnly.toggle()
        if errorsOnly { status = .all }
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    /// Tozalash: kalitlar «suv belgisi» sifatida eslab qolinadi — qayta ulanishda
    /// serverning tail'i ularni qaytarsa ham ro'yxatga tushmaydi. Bekor qilish mumkin.
    func clearLogs() {
        guard !liveByKey.isEmpty || !pendingWhilePaused.isEmpty else { return }
        clearedSnapshot.merge(liveByKey) { _, new in new }
        for item in pendingWhilePaused { clearedSnapshot[item.key] = item }
        if clearedKeys.count > maxLogCapacity * 2 { clearedKeys.removeAll() }
        clearedKeys.formUnion(liveByKey.keys)
        clearedKeys.formUnion(pendingWhilePaused.map(\.key))
        let cleared = liveByKey.count + pendingWhilePaused.count
        liveByKey.removeAll()
        pendingWhilePaused = []
        lastActivityTs = nil
        rebuildFromLive()
        selectedKey = nil
        selectedIsHidden = false
        flash("\(cleared) ta so'rov tozalandi", actionTitle: "Bekor qilish", ttl: 8) { [weak self] in self?.undoClear() }
    }

    var canUndoClear: Bool { !clearedSnapshot.isEmpty }

    func undoClear() {
        guard canUndoClear else { return }
        for (key, log) in clearedSnapshot where liveByKey[key] == nil {
            liveByKey[key] = log
        }
        clearedSnapshot = [:]
        clearedKeys = []
        lastActivityTs = liveByKey.values.compactMap(\.ts).max()
        rebuildFromLive()
        reconcileSelection()
    }

    /// Tanlangan so'rov — filtr uni yashirgan bo'lsa ham qaytadi (`selectedIsHidden` bilan).
    var selectedLog: NetworkLog? {
        guard let selectedKey else { return nil }
        return liveByKey[selectedKey]
    }

    func clearSelection() {
        selectedKey = nil
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

    /// Joriy tab tanasini (redakt holatiga mos) nusxalaydi; menyu ⌥⌘C shu yerga keladi.
    func copySelectedBody() {
        guard let log = selectedLog else { return }
        copy(JSONFormat.body(for: log, tab: detailTab, redact: redactEnabled), what: detailTab.title)
    }

    /// Nusxalashning yagona eshigi: bo'sh matn buferga tushmaydi, har holat aytiladi.
    func copy(_ text: String, what: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "—" else {
            flash("\(what) bo'sh — nusxalanmadi")
            return
        }
        CopyBox.plainText(text)
        flash("Nusxalandi · \(what)")
    }

    func flash(_ text: String, actionTitle: String? = nil, ttl: TimeInterval = 2.4, action: (() -> Void)? = nil) {
        toastTask?.cancel()
        let next = Toast(text: text, actionTitle: actionTitle, action: action)
        toast = next
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ttl))
            guard !Task.isCancelled, let self, self.toast?.id == next.id else { return }
            self.toast = nil
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        toast = nil
    }

    func dismissBanner() {
        banner = nil
    }

    /// ⌘E / ⇧⌘E: ko'rinadigan ro'yxatda keyingi yoki oldingi xatoga o'tadi (4xx/5xx/NET).
    @discardableResult
    func moveToError(forward: Bool) -> Bool {
        let logs = visibleLogs
        guard !logs.isEmpty else { return false }
        let current = selectedKey.flatMap { key in logs.firstIndex(where: { $0.key == key }) }
        let count = logs.count
        let step = forward ? 1 : -1
        let origin = current ?? (forward ? -1 : count)
        let order = (1...count).map { offset in ((origin + step * offset) % count + count) % count }
        guard let idx = order.first(where: { logs[$0].statusClass.isFailure && $0 != current }) else {
            flash(forward ? "Keyingi xato yo'q" : "Oldingi xato yo'q")
            return false
        }
        selectLog(logs[idx])
        return true
    }

    /// Ro'yxat qidiruviga shu endpoint yo'lini qo'yadi — takrorlarni bir bosishda ajratadi.
    func filterEndpoint(_ log: NetworkLog) {
        let path = log.pathOnly
        guard !path.isEmpty else { return }
        applyQuery(query == path ? "" : path)
    }

    func start() async {
        startGeneration += 1
        let gen = startGeneration
        isLoading = true
        cancelLiveWork()
        publishConnection()
        lastServerStartAttempt = Date()
        serverOK = await client.ensureServer(projectRoot: MonitorClient.projectRoot())
        guard gen == startGeneration, !Task.isCancelled else { return }
        if !serverOK {
            banner = "8787 ochilmadi — bash tools/rsid-http-monitor/service.sh start"
            isLoading = false
            publishConnection()
            pollTask = Task { await pollLoop() }
            return
        }
        banner = nil
        await refresh(full: true)
        guard gen == startGeneration, !Task.isCancelled else { return }
        isLoading = false
        publishConnection()
        pollTask = Task { await pollLoop() }
    }

    func clearFilters() {
        selectedAppId = "all"
        status = .all
        selectedMethod = "ALL"
        query = ""
        queryTask?.cancel()
        errorsOnly = false
        if favoritesOnly { favoritesOnly = false }
        slowOnly = false
        selectedHost = nil
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func refresh(full: Bool = false) async {
        do {
            let nextDevices = try await client.devices()
            if Task.isCancelled { return }
            let nextApps = try await client.apps()
            if Task.isCancelled { return }
            let devicesChanged = (nextDevices != devices)
            let appsChanged = (nextApps != apiApps)

            if devicesChanged { devices = nextDevices }
            if appsChanged || full {
                apiApps = nextApps.isEmpty ? AppProfile.builtIn : nextApps
            }
            serverOK = true

            refreshFailures = 0

            if devicesChanged || appsChanged || full || allLogs.isEmpty {
                rebuildFromLive()
                selectedSerial = DeviceScope.resolved(usbSerial: selectedSerial, devices: devices).usbSerial
            }

            syncLiveStreams()
            reconcileSelection()
            if banner != nil, !bannerIsStreamNotice { banner = nil }
            publishConnection()
        } catch {
            refreshFailures += 1
            if refreshFailures >= LogStore.serverDownAfterFailures || !serverOK {
                markServerDown(error)
            }
        }
    }

    func selectDevice(_ serial: String?) {
        guard selectedSerial != serial else { return }
        selectedSerial = serial
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func selectAllDevices() {
        guard selectedSerial != nil else { return }
        selectedSerial = nil
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func toggleFavoritesOnly() {
        favoritesOnly.toggle()
        recomputeDerivedState()
        reconcileSelection()
    }

    func isFavorite(_ key: String) -> Bool {
        favoriteKeys.contains(FavoriteKey.hash(key))
    }

    func toggleFavorite(_ key: String) {
        let h = FavoriteKey.hash(key)
        if favoriteKeys.contains(h) {
            favoriteKeys.remove(h)
        } else {
            favoriteKeys.insert(h)
        }
        favoriteKeys = FavoriteKey.prune(favoriteKeys, live: Set(liveByKey.keys.map(FavoriteKey.hash)))
        UserDefaults.standard.set(Array(favoriteKeys), forKey: "logx.favoriteHashes")
        recomputeDerivedState()
        if favoritesOnly { reconcileSelection() }
    }

    func selectApp(_ id: String) {
        guard selectedAppId != id else { return }
        selectedAppId = id
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func selectMethod(_ next: String) {
        selectedMethod = next
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func selectStatus(_ next: StatusClass) {
        status = next
        if errorsOnly { errorsOnly = false }
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    /// Qidiruv matni darhol saqlanadi, og'ir filtr (body qidiruvi) esa
    /// yozish to'xtagach bir marta hisoblanadi.
    func applyQuery(_ next: String) {
        query = next
        queryTask?.cancel()
        if next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recomputeDerivedState()
            reconcileSelection()
            return
        }
        queryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(LogStore.queryDebounce * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.recomputeDerivedState()
            self.reconcileSelection()
        }
    }

    /// Tanlov o'z-o'zidan boshqa qatorga sakramaydi: log o'chib ketgan bo'lsa
    /// tanlov bo'shaydi, filtr yashirgan bo'lsa «yashirin» belgisi bilan qoladi.
    func reconcileSelection() {
        guard let key = selectedKey else {
            selectedIsHidden = false
            return
        }
        if liveByKey[key] == nil {
            selectedKey = nil
            selectedIsHidden = false
            return
        }
        selectedIsHidden = !cachedVisibleKeys.contains(key)
    }

    /// ↑/↓: ko'rinadigan ro'yxat bo'ylab yuradi; tanlov yo'q bo'lsa chetidan boshlaydi.
    func moveSelection(by delta: Int) {
        let logs = visibleLogs
        guard !logs.isEmpty else { return }
        let current = selectedKey.flatMap { key in logs.firstIndex(where: { $0.key == key }) }
        let next: Int
        if let current {
            next = min(max(current + delta, 0), logs.count - 1)
        } else {
            next = delta < 0 ? logs.count - 1 : 0
        }
        selectLog(logs[next])
    }

    func selectLog(_ log: NetworkLog) {
        if followLatest {
            followLatest = false
            persistPrefs()
            flash("Kuzat o'chdi — ⌘L qaytaradi")
        }
        selectedKey = log.key
        selectedIsHidden = !cachedVisibleKeys.contains(log.key)
    }

    func rebuildFromLive() {
        if liveByKey.count > maxLogCapacity {
            let sortedKeys = liveByKey.values.sorted { ($0.ts ?? 0) < ($1.ts ?? 0) }.map(\.key)
            let excess = liveByKey.count - maxLogCapacity
            for key in sortedKeys.prefix(excess) {
                liveByKey.removeValue(forKey: key)
            }
        }
        allLogs = liveByKey.values
            .filter { LogFilter.isLocal($0) }
            .sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
        apps = AppProfile.merge(api: apiApps, logs: allLogs)
        if selectedAppId != "all", !apps.contains(where: { $0.id == selectedAppId }) {
            selectedAppId = "all"
        }
        recomputeDerivedState()
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var actionTitle: String?
    var action: (() -> Void)?

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}
