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

    private var client = MonitorClient()
    private var liveTasks: [String: Task<Void, Never>] = [:]
    private var liveByKey: [String: NetworkLog] = [:]
    private var apiApps: [AppProfile] = AppProfile.builtIn
    private var detailSeq = DetailSeq()

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
        LogFilter.apply(
            allLogs,
            appId: selectedAppId,
            scope: selectedScope,
            status: status,
            query: query,
            favoritesOnly: favoritesOnly,
            favoriteKeys: favoriteKeys
        )
    }

    func statusCount(_ item: StatusClass) -> Int {
        LogFilter.apply(
            allLogs,
            appId: selectedAppId,
            scope: selectedScope,
            status: item,
            query: query,
            favoritesOnly: favoritesOnly,
            favoriteKeys: favoriteKeys
        ).count
    }

    var selectedLog: NetworkLog? {
        if let selectedKey, let hit = visibleLogs.first(where: { $0.key == selectedKey }) {
            return selectedDetail?.key == hit.key ? (selectedDetail ?? hit) : hit
        }
        return visibleLogs.first
    }

    func start() async {
        isLoading = true
        serverOK = await client.ensureServer(projectRoot: MonitorClient.projectRoot())
        if !serverOK {
            banner = "8787 ochilmadi — bash tools/rsid-http-monitor/service.sh start"
            isLoading = false
            return
        }
        banner = nil
        await refresh(full: true)
        isLoading = false
        Task { await pollLoop() }
    }

    func refresh(full: Bool = false) async {
        do {
            let nextDevices = try await client.devices()
            let nextApps = try await client.apps()
            devices = nextDevices
            apiApps = nextApps.isEmpty ? AppProfile.builtIn : nextApps
            serverOK = true
            rebuildFromLive()
            let pruned = DeviceScope.resolved(
                usbSerial: selectedSerial,
                fieldId: selectedFieldId,
                devices: devices,
                fields: fieldDevices
            )
            selectedSerial = pruned.usbSerial
            selectedFieldId = pruned.fieldId
            syncLiveStreams()
            if full, selectedKey == nil {
                selectedKey = visibleLogs.first?.key
            }
            reconcileSelection()
            if let key = selectedKey, selectedDetail?.key != key || selectedDetail?.isFull != true {
                await loadDetail(key)
            }
            banner = allLogs.isEmpty ? "So‘rov yo‘q — ilovani oching yoki 8787 ni tekshiring" : nil
        } catch {
            serverOK = false
            banner = (error as? MonitorClientError)?.description ?? String(describing: error)
        }
    }

    func selectDevice(_ serial: String?) {
        selectedSerial = serial
        selectedFieldId = nil
        reconcileSelection()
        syncLiveStreams()
    }

    func selectField(_ id: String?) {
        selectedFieldId = id
        selectedSerial = nil
        reconcileSelection()
    }

    func selectAllDevices() {
        selectedSerial = nil
        selectedFieldId = nil
        favoritesOnly = false
        reconcileSelection()
        syncLiveStreams()
    }

    func toggleFavoritesOnly() {
        favoritesOnly.toggle()
        reconcileSelection()
    }

    func toggleFavorite(_ key: String) {
        if favoriteKeys.contains(key) {
            favoriteKeys.remove(key)
        } else {
            favoriteKeys.insert(key)
        }
        UserDefaults.standard.set(Array(favoriteKeys), forKey: "logx.favorites")
    }

    func selectApp(_ id: String) {
        selectedAppId = id
        reconcileSelection()
    }

    func selectStatus(_ next: StatusClass) {
        status = next
        reconcileSelection()
    }

    func applyQuery(_ next: String) {
        query = next
        reconcileSelection()
    }

    private func reconcileSelection() {
        if let key = selectedKey, visibleLogs.contains(where: { $0.key == key }) {
            if selectedDetail?.key != key || selectedDetail?.isFull != true {
                Task { await loadDetail(key) }
            }
            return
        }
        selectedKey = visibleLogs.first?.key
        selectedDetail = nil
        if let key = selectedKey {
            Task { await loadDetail(key) }
        }
    }

    func selectLog(_ log: NetworkLog) {
        selectedKey = log.key
        Task { await loadDetail(log.key) }
    }

    private func loadDetail(_ key: String) async {
        let seq = detailSeq.next()
        let local = liveByKey[key] ?? allLogs.first(where: { $0.key == key })
        if detailSeq.isCurrent(seq) { selectedDetail = local }
    }

    private func rebuildFromLive() {
        allLogs = liveByKey.values
            .filter { LogFilter.isLocal($0) }
            .sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
        apps = AppProfile.merge(api: apiApps, logs: allLogs)
        if selectedAppId != "all", !apps.contains(where: { $0.id == selectedAppId }) {
            selectedAppId = "all"
        }
    }

    private func syncLiveStreams() {
        let wanted: [String]
        if let serial = selectedSerial {
            wanted = [serial]
        } else {
            wanted = devices.map(\.serial)
        }
        for dead in liveTasks.keys where !wanted.contains(dead) {
            liveTasks[dead]?.cancel()
            liveTasks[dead] = nil
        }
        for serial in wanted where liveTasks[serial] == nil {
            liveTasks[serial] = Task { await stream(serial: serial) }
        }
    }

    private func stream(serial: String) async {
        guard let url = URL(string: "http://127.0.0.1:8787/api/http-stream?serial=\(serial)&tail=80") else { return }
        var req = URLRequest(url: url)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        do {
            let (bytes, _) = try await URLSession.shared.bytes(for: req)
            var event = ""
            var dataLines: [String] = []
            for try await line in bytes.lines {
                if Task.isCancelled { break }
                if line.hasPrefix("event:") {
                    event = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                } else if line.isEmpty {
                    if event == "http" {
                        let raw = dataLines.joined()
                        if let item = decodeLive(raw, serial: serial) {
                            liveByKey[item.key] = item
                            rebuildFromLive()
                            if selectedKey == nil { selectedKey = item.key }
                        }
                    }
                    event = ""
                    dataLines = []
                }
            }
        } catch {
            liveTasks[serial] = nil
        }
        if !Task.isCancelled {
            liveTasks[serial] = nil
        }
    }

    private func decodeLive(_ raw: String, serial: String) -> NetworkLog? {
        guard let data = raw.data(using: .utf8) else { return nil }
        guard let env = try? JSONDecoder().decode(LogEnvelope.self, from: data) else { return nil }
        var log = env.value.asLog(key: env.key)
        if log.serial?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            log.serial = serial
        }
        return log
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await refresh()
        }
    }
}
