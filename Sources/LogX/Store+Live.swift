import Foundation
import LogXCore

extension LogStore {
    func publishConnection() {
        connection = AppConnectionResolver.resolve(
            isLoading: isLoading,
            serverOK: serverOK,
            isPaused: isPaused,
            deviceCount: devices.count,
            streams: Array(streamHealthBySerial.values)
        )
    }

    func cancelLiveWork() {
        pollTask?.cancel()
        pollTask = nil
        dropLiveStreams()
    }

    /// Barcha stream tasklarini to'xtatadi; server qaytgach `syncLiveStreams`
    /// ularni yangidan ochadi (osilib qolgan TCP ulanish qayta ishlatilmaydi).
    func dropLiveStreams() {
        for task in liveTasks.values { task.cancel() }
        liveTasks.removeAll()
        streamHealthBySerial.removeAll()
    }

    /// Stream haqidagi banner (`event: error`) refresh muvaffaqiyatida o'chirilmaydi.
    var bannerIsStreamNotice: Bool { banner?.hasPrefix("Stream: ") == true }

    func markServerDown(_ error: Error) {
        let wasUp = serverOK
        serverOK = false
        banner = (error as? MonitorClientError)?.description ?? String(describing: error)
        if wasUp {
            LogXLog.write("server down: \(banner ?? "")")
            dropLiveStreams()
        }
        publishConnection()
    }

    func syncLiveStreams() {
        let wanted = devices.map(\.serial)
        for dead in liveTasks.keys where !wanted.contains(dead) {
            liveTasks[dead]?.cancel()
            liveTasks[dead] = nil
            streamHealthBySerial[dead] = nil
        }
        for serial in wanted {
            if let existing = liveTasks[serial], !existing.isCancelled {
                continue
            }
            setHealth(serial, .connecting)
            liveTasks[serial] = Task { await stream(serial: serial) }
        }
        publishConnection()
    }

    func stream(serial: String) async {
        var delay: TimeInterval = 0
        var attempt = 0
        setHealth(serial, .connecting)
        defer {
            if !Task.isCancelled {
                liveTasks[serial] = nil
            }
        }

        while !Task.isCancelled {
            guard let url = LiveStreamURL.httpStream(base: client.baseURL, serial: serial) else {
                setHealth(serial, .failed("bad url"))
                return
            }
            var req = URLRequest(url: url)
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = LiveStreamPump.idleTimeout

            let startedAt = Date()
            var reason = "eof"
            do {
                try await LiveStreamPump.run(request: req, serial: serial) { chunk in
                    await MainActor.run {
                        self.handleStreamChunk(serial: serial, chunk: chunk)
                    }
                }
            } catch is CancellationError {
                break
            } catch {
                reason = String(describing: error)
            }
            if Task.isCancelled { break }
            let connectedFor = Date().timeIntervalSince(startedAt)
            if connectedFor >= ReconnectBackoff.stableAfter { attempt = 0 }
            attempt += 1
            delay = ReconnectBackoff.afterDrop(current: delay, connectedFor: connectedFor)
            setHealth(serial, .reconnecting(attempt: attempt, nextDelay: delay))
            LogXLog.write("stream drop serial=\(serial) retry=\(attempt) delay=\(delay) \(reason)")
            do {
                try await Task.sleep(nanoseconds: nanoseconds(delay))
            } catch {
                break
            }
        }
    }

    func handleStreamChunk(serial: String, chunk: LiveStreamChunk) {
        switch chunk {
        case .opened:
            setHealth(serial, .live)
        case .logs(let items):
            if bannerIsStreamNotice { banner = nil }
            ingestBatch(items)
            noteUnknownApps(serial: serial, items: items)
        case .serverError(let message):
            banner = "Stream: \(message)"
            LogXLog.write("stream error serial=\(serial) \(message)")
        }
    }

    /// Server pid→paket xaritasini stream ochilganda bir marta quradi; ilova qayta
    /// ishga tushsa hamma yangi log «Noma'lum» bo'ladi. Ketma-ket N noma'lum log
    /// kelsa stream qayta ochiladi (30 s da bir martadan ko'p emas).
    func noteUnknownApps(serial: String, items: [NetworkLog]) {
        var streak = unknownAppStreak[serial] ?? 0
        for item in items {
            streak = item.resolvedAppId == AppProfile.unknownId ? streak + 1 : 0
        }
        unknownAppStreak[serial] = streak
        guard streak >= LogStore.unknownStreakLimit else { return }
        let now = Date()
        if let last = lastUnknownReopen[serial], now.timeIntervalSince(last) < LogStore.unknownReopenThrottle {
            return
        }
        lastUnknownReopen[serial] = now
        unknownAppStreak[serial] = 0
        LogXLog.write("stream reopen serial=\(serial) reason=unknown-app-streak")
        liveTasks[serial]?.cancel()
        liveTasks[serial] = nil
        syncLiveStreams()
    }

    func setHealth(_ serial: String, _ health: StreamHealth) {
        if streamHealthBySerial[serial] == health { return }
        streamHealthBySerial[serial] = health
        publishConnection()
    }

    func ingestBatch(_ items: [NetworkLog]) {
        guard !items.isEmpty else { return }
        if isPaused {
            pendingWhilePaused.append(contentsOf: items.filter { !clearedKeys.contains($0.key) })
            if pendingWhilePaused.count > maxLogCapacity {
                pendingWhilePaused.removeFirst(pendingWhilePaused.count - maxLogCapacity)
            }
            return
        }
        var fresh: [NetworkLog] = []
        var updated = false
        for var item in items {
            if clearedKeys.contains(item.key) { continue }
            if let existing = liveByKey[item.key] {
                if item.ts == nil || (existing.ts ?? 0) > 0 { item.ts = existing.ts }
                if existing != item {
                    liveByKey[item.key] = item
                    queryMatchCache.removeValue(forKey: item.key)
                    updated = true
                }
            } else {
                liveByKey[item.key] = item
                fresh.append(item)
            }
        }
        guard !fresh.isEmpty || updated else { return }
        if let ts = fresh.compactMap(\.ts).max() { lastActivityTs = max(lastActivityTs ?? 0, ts) }
        rebuildFromLive()
        guard !fresh.isEmpty else {
            reconcileSelection()
            return
        }
        if followLatest {
            let visibleNew = fresh.filter { cachedVisibleKeys.contains($0.key) }
            if let key = FollowLatest.selectedKey(batch: visibleNew, currentKey: selectedKey, follow: true, paused: false) {
                selectedKey = key
            }
        }
        reconcileSelection()
    }

    func pollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if Task.isCancelled { break }
            if !serverOK {
                let ok = await recoverServer()
                if Task.isCancelled { break }
                if ok {
                    serverOK = true
                    banner = nil
                    await refresh(full: true)
                    syncLiveStreams()
                }
                continue
            }
            await refresh()
            if Task.isCancelled { break }
            syncLiveStreams()
        }
    }

    /// Server yo'qligida har 3 s ping qilinadi, `service.sh start` esa
    /// 30 s da bir martadan ko'p yurgizilmaydi.
    func recoverServer() async -> Bool {
        if await client.ping() { return true }
        if let last = lastServerStartAttempt, Date().timeIntervalSince(last) < LogStore.serverStartRetryInterval {
            return false
        }
        lastServerStartAttempt = Date()
        return await client.ensureServer(projectRoot: MonitorClient.projectRoot())
    }

    private func nanoseconds(_ delay: TimeInterval) -> UInt64 {
        let clamped = max(0, delay)
        return UInt64(clamped * 1_000_000_000)
    }
}
