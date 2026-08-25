import Foundation
import LogXCore

@MainActor
final class LogStore: ObservableObject {
    @Published var devices: [ConnectedDevice] = []
    @Published var apps: [AppProfile] = AppProfile.builtIn
    @Published var selectedSerial: String?
    @Published var selectedFieldId: String?
    @Published var selectedAppId: String = "all"
    @Published var status: StatusClass = .all
    @Published var query: String = ""
    @Published var favoritesOnly = false
    @Published var favoriteKeys: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "logx.favorites") ?? []
    )
    @Published private(set) var allLogs: [NetworkLog] = []
    @Published var selectedKey: String?
    @Published var selectedDetail: NetworkLog?
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
    @Published var skippedWhilePaused = 0
    @Published var connection: AppConnection = .booting
    @Published var streamHealthBySerial: [String: StreamHealth] = [:]
    @Published var redactEnabled = UserDefaults.standard.bool(forKey: "logx.redact") {
        didSet { UserDefaults.standard.set(redactEnabled, forKey: "logx.redact") }
    }

    let maxLogCapacity = 2500
    var client = MonitorClient()
    var liveTasks: [String: Task<Void, Never>] = [:]
    var pollTask: Task<Void, Never>?
    var startGeneration = 0
    var liveByKey: [String: NetworkLog] = [:]
    var apiApps: [AppProfile] = AppProfile.builtIn
    private var detailSeq = DetailSeq()

    var cachedVisibleLogs: [NetworkLog] = []
    var cachedStatusCounts: [StatusClass: Int] = [:]
    var cachedErrorCount: Int = 0
    var cachedLiveApps: [(app: AppProfile, count: Int)] = []
    var cachedUniqueHosts: [String] = []
    var cachedEndpointCounts: [String: Int] = [:]

    init() {
        let prefs = InspectorPrefs.load()
        hideNoise = prefs.hideNoise
        followLatest = prefs.followLatest
        slowOnly = prefs.slowOnly
        selectedMethod = prefs.selectedMethod
        status = StatusClass(rawValue: prefs.status) ?? .all
        errorsOnly = prefs.errorsOnly
        selectedAppId = prefs.selectedAppId
        selectedSerial = prefs.selectedSerial
    }

    var selectedDevice: ConnectedDevice? {
        devices.first(where: { $0.serial == selectedSerial })
    }

    var fieldDevices: [FieldDevice] {
        FieldDevices.collect(allLogs)
    }

    var selectedScope: DeviceScope {
        DeviceScope.resolved(
            usbSerial: selectedSerial,
            fieldId: selectedFieldId,
            devices: devices,
            fields: fieldDevices
        ).scope
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
        if !isPaused { skippedWhilePaused = 0 }
        publishConnection()
    }

    func toggleErrorsOnly() {
        errorsOnly.toggle()
        if errorsOnly { status = .all }
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func clearLogs() {
        liveByKey.removeAll()
        skippedWhilePaused = 0
        rebuildFromLive()
        selectedKey = nil
        selectedDetail = nil
    }

    var selectedLog: NetworkLog? {
        if let selectedKey, let hit = visibleLogs.first(where: { $0.key == selectedKey }) {
            return selectedDetail?.key == hit.key ? (selectedDetail ?? hit) : hit
        }
        return visibleLogs.first
    }

    func start() async {
        startGeneration += 1
        let gen = startGeneration
        isLoading = true
        cancelLiveWork()
        publishConnection()
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

            if devicesChanged || appsChanged || full || allLogs.isEmpty {
                rebuildFromLive()
                let pruned = DeviceScope.resolved(
                    usbSerial: selectedSerial,
                    fieldId: selectedFieldId,
                    devices: devices,
                    fields: fieldDevices
                )
                selectedSerial = pruned.usbSerial
                selectedFieldId = pruned.fieldId
            }

            syncLiveStreams()

            if full, selectedKey == nil {
                selectedKey = visibleLogs.first?.key
            }
            reconcileSelection()
            if let key = selectedKey, selectedDetail?.key != key || selectedDetail?.isFull != true {
                await loadDetail(key)
            }
            banner = nil
            publishConnection()
        } catch {
            serverOK = false
            banner = (error as? MonitorClientError)?.description ?? String(describing: error)
            syncLiveStreams()
            publishConnection()
        }
    }

    func selectDevice(_ serial: String?) {
        guard selectedSerial != serial || selectedFieldId != nil else { return }
        selectedSerial = serial
        selectedFieldId = nil
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func selectField(_ id: String?) {
        guard selectedFieldId != id || selectedSerial != nil else { return }
        selectedFieldId = id
        selectedSerial = nil
        recomputeDerivedState()
        reconcileSelection()
    }

    func selectAllDevices() {
        guard selectedSerial != nil || selectedFieldId != nil || favoritesOnly else { return }
        selectedSerial = nil
        selectedFieldId = nil
        favoritesOnly = false
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func toggleFavoritesOnly() {
        favoritesOnly.toggle()
        recomputeDerivedState()
        reconcileSelection()
    }

    func toggleFavorite(_ key: String) {
        if favoriteKeys.contains(key) {
            favoriteKeys.remove(key)
        } else {
            favoriteKeys.insert(key)
        }
        UserDefaults.standard.set(Array(favoriteKeys), forKey: "logx.favorites")
        recomputeDerivedState()
    }

    func selectApp(_ id: String) {
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

    func applyQuery(_ next: String) {
        query = next
        recomputeDerivedState()
        reconcileSelection()
    }

    func reconcileSelection() {
        if let key = selectedKey, visibleLogs.contains(where: { $0.key == key }) {
            if selectedDetail?.key != key || selectedDetail?.isFull != true {
                Task { await loadDetail(key) }
            }
            return
        }
        let nextKey = visibleLogs.first?.key
        if selectedKey != nextKey {
            selectedKey = nextKey
            selectedDetail = nil
            if let key = selectedKey {
                Task { await loadDetail(key) }
            }
        }
    }

    func selectLog(_ log: NetworkLog) {
        followLatest = false
        selectedKey = log.key
        persistPrefs()
        Task { await loadDetail(log.key) }
    }

    func loadDetail(_ key: String) async {
        let seq = detailSeq.next()
        let local = liveByKey[key] ?? allLogs.first(where: { $0.key == key })
        if detailSeq.isCurrent(seq) { selectedDetail = local }
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
