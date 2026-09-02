import AppKit
import Foundation
import LogXCore
import UniformTypeIdentifiers

extension LogStore {
    func recomputeDerivedState() {
        var appCounts: [String: Int] = [:]
        for log in allLogs {
            appCounts[log.resolvedAppId, default: 0] += 1
        }
        cachedLiveApps = apps.compactMap { app in
            guard let count = appCounts[app.id] else { return nil }
            return (app, count)
        }

        let scope = selectedScope
        var scoped: [NetworkLog] = []
        var noiseHidden = 0
        for log in allLogs
        where LogFilter.matchesApp(log, appId: selectedAppId) && LogFilter.matchesDevice(log, scope: scope) {
            if hideNoise, LogNoise.isNoise(log) {
                noiseHidden += 1
                continue
            }
            scoped.append(log)
        }
        cachedScopedCount = scoped.count + noiseHidden
        cachedNoiseHiddenCount = noiseHidden
        cachedUniqueHosts = EndpointIdentity.uniqueHosts(scoped)
        if let host = selectedHost, !host.isEmpty, !cachedUniqueHosts.contains(host) {
            selectedHost = nil
        }

        let cheap = LogFilter.apply(
            scoped,
            appId: nil,
            scope: .all,
            status: .all,
            query: "",
            favoritesOnly: favoritesOnly,
            favoriteKeys: favoriteKeys,
            errorsOnly: false,
            method: selectedMethod,
            hideNoise: false,
            slowOnly: slowOnly,
            selectedHost: selectedHost
        )
        let base = applyQueryMemo(cheap)
        var counts: [StatusClass: Int] = [
            .all: 0, .ok2xx: 0, .redirect3xx: 0, .err4xx: 0, .err5xx: 0, .net: 0,
        ]
        for log in base {
            counts[.all, default: 0] += 1
            counts[log.statusClass, default: 0] += 1
        }
        cachedStatusCounts = counts
        cachedErrorCount = (counts[.err4xx] ?? 0) + (counts[.err5xx] ?? 0) + (counts[.net] ?? 0)

        if errorsOnly {
            cachedVisibleLogs = base.filter { LogFilter.errorClasses.contains($0.statusClass) }
        } else if status == .all {
            cachedVisibleLogs = base
        } else {
            cachedVisibleLogs = base.filter { $0.statusClass == status }
        }
        cachedVisibleKeys = Set(cachedVisibleLogs.map(\.key))
        cachedEndpointCounts = EndpointIdentity.counts(in: cachedVisibleLogs)
        cachedLiveFavoriteCount = favoriteKeys.isEmpty ? 0 : allLogs.reduce(0) { $0 + (favoriteKeys.contains(FavoriteKey.hash($1.key)) ? 1 : 0) }
        publishConnection()
    }

    /// Tana bo'ylab qidiruv har log uchun bir marta hisoblanadi: har yangi batch'da
    /// faqat yangi kalitlar tekshiriladi, kesh so'rov matni o'zgarganda tozalanadi.
    func applyQueryMemo(_ logs: [NetworkLog]) -> [NetworkLog] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            queryMatchCache.removeAll(keepingCapacity: true)
            queryMatchCacheFor = ""
            return logs
        }
        if queryMatchCacheFor != q {
            queryMatchCache.removeAll(keepingCapacity: true)
            queryMatchCacheFor = q
        }
        var out: [NetworkLog] = []
        out.reserveCapacity(logs.count)
        for log in logs {
            let hit: Bool
            if let cached = queryMatchCache[log.key] {
                hit = cached
            } else {
                hit = LogFilter.matchesQuery(log, query: q)
                queryMatchCache[log.key] = hit
            }
            if hit { out.append(log) }
        }
        if queryMatchCache.count > maxLogCapacity * 2 {
            let live = Set(logs.map(\.key))
            queryMatchCache = queryMatchCache.filter { live.contains($0.key) }
        }
        return out
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
