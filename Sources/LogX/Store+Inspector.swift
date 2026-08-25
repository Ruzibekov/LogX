import AppKit
import Foundation
import LogXCore
import UniformTypeIdentifiers

extension LogStore {
    func recomputeDerivedState() {
        var appCounts: [String: Int] = [:]
        for log in allLogs where LogFilter.isLocal(log) {
            appCounts[log.resolvedAppId, default: 0] += 1
        }
        cachedLiveApps = apps.compactMap { app in
            guard let count = appCounts[app.id] else { return nil }
            return (app, count)
        }

        let scope = selectedScope
        cachedUniqueHosts = EndpointIdentity.uniqueHosts(
            allLogs.filter { log in
                LogFilter.isLocal(log)
                    && LogFilter.matchesApp(log, appId: selectedAppId)
                    && LogFilter.matchesDevice(log, scope: scope)
                    && (!hideNoise || !LogNoise.isNoise(log))
            }
        )
        if let host = selectedHost, !host.isEmpty, !cachedUniqueHosts.contains(host) {
            selectedHost = nil
        }

        let counts = LogFilter.statusCounts(
            allLogs,
            appId: selectedAppId,
            scope: scope,
            query: query,
            favoritesOnly: favoritesOnly,
            favoriteKeys: favoriteKeys,
            method: selectedMethod,
            hideNoise: hideNoise,
            slowOnly: slowOnly,
            selectedHost: selectedHost
        )
        cachedStatusCounts = counts
        cachedErrorCount = (counts[.err4xx] ?? 0) + (counts[.err5xx] ?? 0) + (counts[.net] ?? 0)

        cachedVisibleLogs = LogFilter.apply(
            allLogs,
            appId: selectedAppId,
            scope: scope,
            status: status,
            query: query,
            favoritesOnly: favoritesOnly,
            favoriteKeys: favoriteKeys,
            errorsOnly: errorsOnly,
            method: selectedMethod,
            hideNoise: hideNoise,
            slowOnly: slowOnly,
            selectedHost: selectedHost
        )
        cachedEndpointCounts = EndpointIdentity.counts(in: cachedVisibleLogs)
        publishConnection()
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
            Task { await loadDetail(first.key) }
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

    func exportHAR() {
        presentSave(name: "logx-session.har", data: SessionExport.har(logs: visibleLogs, redact: redactEnabled))
    }

    func exportJSON() {
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
        let handler: (NSApplication.ModalResponse) -> Void = { result in
            guard result == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }
}
