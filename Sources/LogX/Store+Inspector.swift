import AppKit
import Foundation
import LogXCore
import UniformTypeIdentifiers

extension LogStore {
    func recomputeDerivedState() {
        let scope = selectedScope
        collectAppCounts()
        collectScope(scope: scope)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        prepareQueryMemo(trimmedQuery)
        collectVisible(scope: scope, query: trimmedQuery)
        cachedLiveFavoriteCount = favoriteKeys.isEmpty ? 0 : allLogs.reduce(0) { $0 + (favoriteKeys.contains(FavoriteKey.hash($1.key)) ? 1 : 0) }
        publishConnection()
    }

    private func collectAppCounts() {
        appCountsBuffer.removeAll(keepingCapacity: true)
        for log in allLogs {
            appCountsBuffer[log.resolvedAppId, default: 0] += 1
        }
        cachedLiveApps = apps.compactMap { app in
            guard let count = appCountsBuffer[app.id] else { return nil }
            return (app, count)
        }
    }

    private func collectScope(scope: DeviceScope) {
        var noiseHidden = 0
        var scoped = 0
        let wantedApp = resolvedAppFilter()
        hostsBuffer.removeAll(keepingCapacity: true)
        for log in allLogs
        where matchesApp(log, wanted: wantedApp) && LogFilter.matchesDevice(log, scope: scope) {
            scoped += 1
            if hideNoise, log.isNoise {
                noiseHidden += 1
                continue
            }
            if !log.hostLabel.isEmpty { hostsBuffer.insert(log.hostLabel) }
        }
        cachedScopedCount = scoped
        cachedNoiseHiddenCount = noiseHidden
        cachedUniqueHosts = hostsBuffer.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if let host = selectedHost, !host.isEmpty, !cachedUniqueHosts.contains(host) {
            selectedHost = nil
        }
    }

    private func resolvedAppFilter() -> String? {
        let raw = selectedAppId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != "all" else { return nil }
        return AppProfile.resolveId(raw)
    }

    private func matchesApp(_ log: NetworkLog, wanted: String?) -> Bool {
        guard let wanted else { return true }
        return log.resolvedAppId == wanted
    }

    private func normalizedMethodFilter() -> String? {
        let raw = selectedMethod.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return (raw.isEmpty || raw == "ALL") ? nil : raw
    }

    private func collectVisible(scope: DeviceScope, query trimmedQuery: String) {
        var counts: [StatusClass: Int] = [
            .all: 0, .ok2xx: 0, .redirect3xx: 0, .err4xx: 0, .err5xx: 0, .net: 0,
        ]
        let statusFilter: StatusClass? = (errorsOnly || status == .all) ? nil : status
        let wantedApp = resolvedAppFilter()
        let wantedMethod = normalizedMethodFilter()
        let wantedHost = (selectedHost?.isEmpty == false) ? selectedHost : nil
        cachedVisibleLogs.removeAll(keepingCapacity: true)
        cachedVisibleKeys.removeAll(keepingCapacity: true)
        cachedEndpointCounts.removeAll(keepingCapacity: true)
        for log in allLogs {
            guard matchesApp(log, wanted: wantedApp),
                  LogFilter.matchesDevice(log, scope: scope) else { continue }
            if hideNoise, log.isNoise { continue }
            if let wantedMethod, log.method != wantedMethod { continue }
            if let wantedHost, log.hostLabel.caseInsensitiveCompare(wantedHost) != .orderedSame { continue }
            guard LogFilter.matchesSlow(log, slowOnly: slowOnly) else { continue }
            if favoritesOnly, !favoriteKeys.contains(FavoriteKey.hash(log.key)) { continue }
            if !trimmedQuery.isEmpty, !queryHit(log, query: trimmedQuery) { continue }
            let statusClass = log.statusClass
            counts[.all, default: 0] += 1
            counts[statusClass, default: 0] += 1
            if errorsOnly {
                guard statusClass.isFailure else { continue }
            } else if let statusFilter, statusClass != statusFilter {
                continue
            }
            cachedVisibleLogs.append(log)
            cachedVisibleKeys.insert(log.key)
            cachedEndpointCounts[EndpointIdentity.hash(for: log), default: 0] += 1
        }
        cachedStatusCounts = counts
        cachedErrorCount = (counts[.err4xx] ?? 0) + (counts[.err5xx] ?? 0) + (counts[.net] ?? 0)
        sortVisible()
    }

    private func sortVisible() {
        guard sortField != .time || sortOrder != .descending else { return }
        cachedVisibleLogs.sort { a, b in
            let comp: Bool
            switch sortField {
            case .time:
                comp = (a.ts ?? 0) < (b.ts ?? 0)
            case .method:
                comp = a.method < b.method
            case .status:
                comp = (a.responseCode ?? 0) < (b.responseCode ?? 0)
            case .duration:
                comp = (a.durationMs ?? 0) < (b.durationMs ?? 0)
            case .path:
                comp = a.pathOnly < b.pathOnly
            }
            return sortOrder == .ascending ? comp : !comp
        }
    }

    private func prepareQueryMemo(_ trimmedQuery: String) {
        guard !trimmedQuery.isEmpty else {
            queryMatchCache.removeAll(keepingCapacity: true)
            queryMatchCacheFor = ""
            return
        }
        if queryMatchCacheFor != trimmedQuery {
            queryMatchCache.removeAll(keepingCapacity: true)
            queryMatchCacheFor = trimmedQuery
        }
        if queryMatchCache.count > maxLogCapacity * 2 {
            queryMatchCache.removeAll(keepingCapacity: true)
        }
    }

    private func queryHit(_ log: NetworkLog, query: String) -> Bool {
        if let cached = queryMatchCache[log.key] { return cached }
        let hit = LogFilter.matchesSmartQuery(log, query: query)
        queryMatchCache[log.key] = hit
        return hit
    }

    func persistPrefs() {
        InspectorPrefs(
            hideNoise: hideNoise,
            followLatest: followLatest,
            slowOnly: slowOnly,
            selectedMethod: selectedMethod,
            status: status.rawValue,
            errorsOnly: errorsOnly,
            selectedAppId: selectedAppId,
            selectedSerial: selectedSerial
        ).save()
    }

    func toggleHideNoise() {
        hideNoise.toggle()
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func toggleFollowLatest() {
        followLatest.toggle()
        persistPrefs()
        if followLatest, !isPaused, let first = visibleLogs.first {
            selectedKey = first.key
        }
    }

    func toggleSlowOnly() {
        slowOnly.toggle()
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func selectHost(_ host: String?) {
        if selectedHost == host {
            selectedHost = nil
        } else {
            selectedHost = host
        }
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    var canExport: Bool { !visibleLogs.isEmpty }

    func exportHAR() {
        guard canExport else { return }
        presentSave(name: "logx-session.har", data: SessionExport.har(logs: visibleLogs, redact: redactEnabled))
    }

    func exportJSON() {
        guard canExport else { return }
        presentSave(name: "logx-session.json", data: SessionExport.json(logs: visibleLogs, redact: redactEnabled))
    }

    func presentSave(name: String, data: Data) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = name
        if name.hasSuffix(".har") {
            panel.allowedContentTypes = [UTType(filenameExtension: "har") ?? .json]
        } else {
            panel.allowedContentTypes = [.json]
        }
        let window = NSApp.keyWindow ?? NSApp.mainWindow
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                self?.flash("Saqlandi · \(url.lastPathComponent)", actionTitle: "Finder'da ko'rsatish", ttl: 8) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                self?.presentError(title: "Fayl saqlanmadi", message: "\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    func presentError(title: String, message: String) {
        LogXLog.write("error: \(title) — \(message)")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Yopish")
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
