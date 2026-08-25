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
        for task in liveTasks.values { task.cancel() }
        liveTasks.removeAll()
        streamHealthBySerial.removeAll()
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
        var delay = ReconnectBackoff.initial
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
            req.timeoutInterval = .infinity

            do {
                try await LiveStreamPump.run(request: req, serial: serial) { chunk in
                    await MainActor.run {
                        self.handleStreamChunk(serial: serial, chunk: chunk)
                    }
                }
                if Task.isCancelled { break }
                delay = ReconnectBackoff.initial
                attempt += 1
                setHealth(serial, .reconnecting(attempt: attempt, nextDelay: delay))
                LogXLog.write("stream drop serial=\(serial) eof retry=\(attempt) delay=\(delay)")
                try await Task.sleep(nanoseconds: nanoseconds(delay))
                delay = ReconnectBackoff.next(delay)
            } catch is CancellationError {
                break
            } catch {
                if Task.isCancelled { break }
                attempt += 1
                setHealth(serial, .reconnecting(attempt: attempt, nextDelay: delay))
                LogXLog.write("stream drop serial=\(serial) retry=\(attempt) delay=\(delay) \(error)")
                try? await Task.sleep(nanoseconds: nanoseconds(delay))
                delay = ReconnectBackoff.next(delay)
            }
        }
    }

    func handleStreamChunk(serial: String, chunk: LiveStreamChunk) {
        switch chunk {
        case .opened:
            setHealth(serial, .live)
        case .logs(let items):
            ingestBatch(items)
        }
    }

    func setHealth(_ serial: String, _ health: StreamHealth) {
        if streamHealthBySerial[serial] == health { return }
        streamHealthBySerial[serial] = health
        publishConnection()
    }

    func ingestBatch(_ items: [NetworkLog]) {
        guard !items.isEmpty else { return }
        for item in items {
            lastActivityTs = item.ts
            if isPaused { continue }
            liveByKey[item.key] = item
            if selectedKey == nil { selectedKey = item.key }
        }
        if !isPaused {
            rebuildFromLive()
        }
    }

    func decodeLive(_ raw: String, serial: String) -> NetworkLog? {
        LiveLogDecoder.decode(raw, serial: serial)
    }

    func pollLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if Task.isCancelled { break }
            if !serverOK {
                let ok = await client.ensureServer(projectRoot: MonitorClient.projectRoot())
                if Task.isCancelled { break }
                if ok {
                    serverOK = true
                    banner = nil
                    await refresh(full: true)
                    syncLiveStreams()
                    continue
                }
            }
            await refresh()
            if Task.isCancelled { break }
            syncLiveStreams()
        }
    }

    private func nanoseconds(_ delay: TimeInterval) -> UInt64 {
        let clamped = max(0, delay)
        return UInt64(clamped * 1_000_000_000)
    }
}
