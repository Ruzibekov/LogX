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
    @Published var followLatest = true
    @Published var slowOnly = false
    @Published var selectedHost: String?
    @Published var lastActivityTs: Double?
    /// Pauza paytida kelgan loglar tashlanmaydi — buferda turadi, davom etilganda kiradi.
    @Published var pendingWhilePaused: [NetworkLog] = []
    /// Tanlangan so'rov hozirgi filtr bilan ro'yxatda ko'rinmayapti.
    @Published var selectedIsHidden = false
    /// Qisqa xabar (nusxalandi, tozalandi…) — ixtiyoriy amal tugmasi bilan.
    @Published var toast: Toast?
    @Published var replayInFlight: Set<String> = []
    @Published var diffAnchorKey: String?
    @Published var diffPair: DiffPair?
    @Published var sortField: LogSortField = .time
    @Published var sortOrder: SortOrder = .descending
    @Published var replayComposerLog: NetworkLog?
    var replayPerformer: (NetworkLog) async -> ReplayResult = { await Replay.perform($0) }
    var replayConfirm: (NetworkLog) -> Bool = LogStore.confirmMutatingReplay
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
    var bodyBytesEstimate = 0
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

    func toggleErrorsOnly() {
        errorsOnly.toggle()
        if errorsOnly { status = .all }
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
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

    func selectApp(_ id: String) {
        guard selectedAppId != id else { return }
        selectedAppId = id
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
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

    func selectKey(_ key: String) {
        guard let log = liveByKey[key] else { return }
        selectLog(log)
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

    func enforceBodyBudget() {
        guard bodyBytesEstimate > BodyBudget.totalBodyBytes else { return }
        let sizes = liveByKey.values
            .sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
            .map { (key: $0.key, bytes: BodyBudget.bytes($0)) }
        let drop = BodyBudget.keysToDrop(
            sizes: sizes,
            protected: selectedKey.map { [$0] } ?? []
        )
        for key in drop {
            guard let log = liveByKey[key] else { continue }
            liveByKey[key] = BodyBudget.dropBodies(log)
        }
        bodyBytesEstimate = liveByKey.values.reduce(0) { $0 + BodyBudget.bytes($1) }
    }

    func rebuildFromLive() {
        if liveByKey.count > maxLogCapacity {
            let sortedKeys = liveByKey.values.sorted { ($0.ts ?? 0) < ($1.ts ?? 0) }.map(\.key)
            let excess = liveByKey.count - maxLogCapacity
            for key in sortedKeys.prefix(excess) {
                if let gone = liveByKey.removeValue(forKey: key) {
                    bodyBytesEstimate -= BodyBudget.bytes(gone)
                }
            }
        }
        enforceBodyBudget()
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

