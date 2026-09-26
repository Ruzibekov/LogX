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

    func markServerDown(_ error: Error) {
        let wasUp = serverOK
        serverOK = false
        setBanner((error as? MonitorClientError)?.description ?? String(describing: error))
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
            guard let url = LiveStreamURL.httpStream(base: client.baseURL, serial: serial, tail: 1000) else {
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
            if bannerIsStreamNotice { setBanner(nil) }
            ingestBatch(items)
            noteUnknownApps(serial: serial, items: items)
        case .serverError(let message):
            LogXLog.write("stream error serial=\(serial) \(message)")
            guard let notice = StreamNoticeParser.notice(for: message) else { return }
            setBanner(notice.text, stream: true)
        }
    }

    /// Server pid→paket xaritasini stream ochilganda bir marta quradi; ilova qayta
    /// ishga tushsa hamma yangi log «Noma'lum» bo'ladi. Ketma-ket N noma'lum log
    /// kelsa stream qayta ochiladi (30 s da bir martadan ko'p emas).
    func noteUnknownApps(serial: String, items: [NetworkLog]) {
        var streak = unknownAppStreak[serial] ?? 0
        var counted = unknownStreakKeys[serial] ?? []
        for item in items where !item.isPending {
            if item.resolvedAppId == AppProfile.unknownId {
                if counted.insert(item.key).inserted { streak += 1 }
            } else {
                streak = 0
                counted.removeAll()
            }
        }
        unknownAppStreak[serial] = streak
        unknownStreakKeys[serial] = counted
        guard streak >= LogStore.unknownStreakLimit else { return }
        let now = Date()
        if let last = lastUnknownReopen[serial], now.timeIntervalSince(last) < LogStore.unknownReopenThrottle {
            return
        }
        lastUnknownReopen[serial] = now
        unknownAppStreak[serial] = 0
        unknownStreakKeys[serial] = nil
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
            for item in items where !clearedKeys.contains(item.key) {
                bufferWhilePaused(BodyBudget.clamp(item))
            }
            if pendingWhilePaused.count > maxLogCapacity {
                pendingWhilePaused.removeFirst(pendingWhilePaused.count - maxLogCapacity)
            }
            enforcePausedBudget()
            return
        }
        var fresh: [NetworkLog] = []
        var updated = false
        for rawItem in items {
            var item = BodyBudget.clamp(rawItem)
            if clearedKeys.contains(item.key) { continue }
            if let existing = liveByKey[item.key] {
                if item.isPending && !existing.isPending { continue }
                if item.ts == nil || (existing.ts ?? 0) > 0 { item.ts = existing.ts }
                if existing != item {
                    upsertLive(item)
                    queryMatchCache.removeValue(forKey: item.key)
                    updated = true
                }
            } else {
                upsertLive(item)
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

    private func bufferWhilePaused(_ incoming: NetworkLog) {
        var item = incoming
        if let idx = pendingWhilePaused.lastIndex(where: { $0.key == item.key }) {
            let buffered = pendingWhilePaused[idx]
            if item.isPending && !buffered.isPending { return }
            if item.ts == nil || (buffered.ts ?? 0) > 0 { item.ts = buffered.ts }
            pendingWhilePaused.remove(at: idx)
        }
        pendingWhilePaused.append(item)
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
                    setBanner(nil)
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
