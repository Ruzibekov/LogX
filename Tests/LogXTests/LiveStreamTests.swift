import XCTest
@testable import LogXCore

final class LiveStreamTests: XCTestCase {
    func testReconnectBackoffSequenceAndCap() {
        var delay = ReconnectBackoff.initial
        var sequence: [TimeInterval] = [delay]
        for _ in 0..<6 {
            delay = ReconnectBackoff.next(delay)
            sequence.append(delay)
        }
        XCTAssertEqual(sequence.count, 7)
        let expected: [TimeInterval] = [0.4, 0.8, 1.6, 3.2, 6.4, 8, 8]
        for (got, want) in zip(sequence, expected) {
            XCTAssertEqual(got, want, accuracy: 0.000_001, "\(sequence) != \(expected)")
        }
        XCTAssertEqual(ReconnectBackoff.next(8), 8, accuracy: 0.000_001)
        XCTAssertEqual(ReconnectBackoff.next(0), 0.8, accuracy: 0.000_001)
        XCTAssertGreaterThan(ReconnectBackoff.next(-1), 0)
    }

    func testLiveStreamURLEncodesReservedSerial() {
        let url = LiveStreamURL.httpStream(
            base: URL(string: "http://127.0.0.1:8787")!,
            serial: "A B+C/D"
        )
        XCTAssertNotNil(url)
        let raw = url!.absoluteString
        XCTAssertTrue(raw.contains("serial="), raw)
        XCTAssertTrue(raw.contains("tail=80"), raw)
        XCTAssertFalse(raw.contains("serial=A B"), raw)
        XCTAssertFalse(raw.contains("B+C"), raw)
        XCTAssertFalse(raw.contains("C/D"), raw)
        XCTAssertTrue(raw.contains("A%20B"), raw)
        XCTAssertTrue(raw.lowercased().contains("%2b"), raw)
        XCTAssertTrue(raw.lowercased().contains("%2f"), raw)
        XCTAssertTrue(raw.contains("/api/http-stream"), raw)
    }

    func testLiveStreamURLEmptySerialStillBuilds() {
        let url = LiveStreamURL.httpStream(
            base: URL(string: "http://127.0.0.1:8787")!,
            serial: "",
            tail: 10
        )
        XCTAssertNotNil(url)
        let raw = url!.absoluteString
        XCTAssertTrue(raw.contains("serial="), raw)
        XCTAssertTrue(raw.contains("tail=10"), raw)
    }

    func testResolverBooting() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: true, serverOK: false, isPaused: false, deviceCount: 0, streams: []
            ),
            .booting
        )
    }

    func testResolverServerDown() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false, serverOK: false, isPaused: false, deviceCount: 2, streams: [.live]
            ),
            .serverDown
        )
    }

    func testResolverNoDevice() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false, serverOK: true, isPaused: false, deviceCount: 0, streams: []
            ),
            .noDevice
        )
    }

    func testResolverConnecting() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false, serverOK: true, isPaused: false, deviceCount: 1, streams: [.connecting]
            ),
            .connecting
        )
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false, serverOK: true, isPaused: false, deviceCount: 1, streams: [.connecting]
            ),
            .connecting
        )
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false, serverOK: true, isPaused: false, deviceCount: 1, streams: []
            ),
            .connecting
        )
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false,
                serverOK: true,
                isPaused: false,
                deviceCount: 1,
                streams: [.failed("timeout")]
            ),
            .connecting
        )
    }

    func testResolverLive() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false,
                serverOK: true,
                isPaused: false,
                deviceCount: 2,
                streams: [.connecting, .live]
            ),
            .live
        )
    }

    func testResolverLiveBeatsReconnecting() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false,
                serverOK: true,
                isPaused: false,
                deviceCount: 2,
                streams: [.reconnecting(attempt: 3, nextDelay: 1.6), .live]
            ),
            .live
        )
    }

    func testResolverReconnecting() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false,
                serverOK: true,
                isPaused: false,
                deviceCount: 1,
                streams: [.reconnecting(attempt: 2, nextDelay: 0.8)]
            ),
            .reconnecting
        )
    }

    func testResolverPaused() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false, serverOK: true, isPaused: true, deviceCount: 1, streams: [.live]
            ),
            .paused
        )
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false, serverOK: true, isPaused: true, deviceCount: 0, streams: []
            ),
            .paused
        )
    }

    func testResolverPausedWhenServerDownIsServerDown() {
        XCTAssertEqual(
            AppConnectionResolver.resolve(
                isLoading: false, serverOK: false, isPaused: true, deviceCount: 1, streams: [.live]
            ),
            .serverDown
        )
    }

    func testAppConnectionLiveCopy() {
        XCTAssertEqual(AppConnection.live.title, "8787 · jonli")
        XCTAssertEqual(AppConnection.live.subtitle, "USB stream faol")
        XCTAssertEqual(AppConnection.serverDown.title, "8787 · yo'q")
        XCTAssertFalse(AppConnection.connecting.title.contains("jonli"))
        XCTAssertFalse(AppConnection.reconnecting.title.contains("jonli"))
    }

    func testSSEPendingBufferHappyLine() {
        var buffer = SSEPendingBuffer(maxBytes: 32)
        XCTAssertEqual(buffer.push(0x61), .pending) // a
        XCTAssertEqual(buffer.push(0x62), .pending) // b
        XCTAssertEqual(buffer.push(0x0A), .line("ab"))
        XCTAssertEqual(buffer.push(0x0A), .line(""))
    }

    func testSSEPendingBufferOversizeDropped() {
        var buffer = SSEPendingBuffer(maxBytes: 4)
        XCTAssertEqual(buffer.push(0x61), .pending)
        XCTAssertEqual(buffer.push(0x62), .pending)
        XCTAssertEqual(buffer.push(0x63), .pending)
        XCTAssertEqual(buffer.push(0x64), .pending)
        XCTAssertEqual(buffer.push(0x65), .pending) // exceeds cap, start dropping
        XCTAssertEqual(buffer.push(0x66), .pending)
        XCTAssertEqual(buffer.push(0x0A), .dropped)
    }

    func testSSEPendingBufferRecoversAfterDrop() {
        var buffer = SSEPendingBuffer(maxBytes: 3)
        for _ in 0..<8 { _ = buffer.push(0x58) }
        XCTAssertEqual(buffer.push(0x0A), .dropped)
        XCTAssertEqual(buffer.push(0x6F), .pending) // o
        XCTAssertEqual(buffer.push(0x6B), .pending) // k
        XCTAssertEqual(buffer.push(0x0A), .line("ok"))
    }

    func testSSEPendingBufferFlushTailEmptyAndPending() {
        var empty = SSEPendingBuffer(maxBytes: 8)
        XCTAssertNil(empty.flushTail())

        var pending = SSEPendingBuffer(maxBytes: 8)
        _ = pending.push(0x7A)
        XCTAssertEqual(pending.flushTail(), "z")
        XCTAssertNil(pending.flushTail())

        var dropping = SSEPendingBuffer(maxBytes: 1)
        _ = dropping.push(0x61)
        _ = dropping.push(0x62)
        XCTAssertNil(dropping.flushTail())
    }

    func testSSEPendingBufferDefaultCap() {
        XCTAssertEqual(SSEPendingBuffer.defaultMaxBytes, 1_048_576)
        var buffer = SSEPendingBuffer()
        var sawNonPending = false
        for _ in 0..<SSEPendingBuffer.defaultMaxBytes {
            if buffer.push(0x41) != .pending { sawNonPending = true }
        }
        XCTAssertFalse(sawNonPending)
        XCTAssertEqual(buffer.push(0x42), .pending)
        XCTAssertEqual(buffer.push(0x0A), .dropped)
        XCTAssertEqual(buffer.push(0x78), .pending)
        XCTAssertEqual(buffer.push(0x0A), .line("x"))
    }

    func testMonitorSessionsDedicatedTimeouts() {
        let rest = MonitorSessions.rest.configuration
        XCTAssertEqual(rest.timeoutIntervalForRequest, 12, accuracy: 0.01)
        XCTAssertEqual(rest.timeoutIntervalForResource, 30, accuracy: 0.01)
        XCTAssertEqual(rest.requestCachePolicy, .reloadIgnoringLocalCacheData)

        let stream = MonitorSessions.stream.configuration
        XCTAssertTrue(stream.timeoutIntervalForRequest.isInfinite, "\(stream.timeoutIntervalForRequest)")
        XCTAssertTrue(stream.timeoutIntervalForResource.isInfinite, "\(stream.timeoutIntervalForResource)")
        XCTAssertEqual(stream.requestCachePolicy, .reloadIgnoringLocalCacheData)
        let accept = stream.httpAdditionalHeaders?["Accept"] as? String
        XCTAssertEqual(accept, "text/event-stream")
    }

    func testMonitorClientSourceHasNoSharedSessionOrNetworkLogs() throws {
        let src = try Self.repoSource("Sources/LogXCore/MonitorClient.swift")
        XCTAssertFalse(src.contains("/api/network-logs"), src)
        XCTAssertFalse(src.contains("/api/demo-network-logs"), src)
        XCTAssertFalse(src.contains("URLSession.shared"), src)
        XCTAssertTrue(src.contains("MonitorSessions.rest"), src)
        XCTAssertFalse(src.contains("func logs("), src)
    }

    func testStoreSourceReconnectsAndSkipsSharedSession() throws {
        let storeMain = try Self.repoSource("Sources/LogX/Store.swift")
        let storeLive = try Self.repoSource("Sources/LogX/Store+Live.swift")
        let pump = try Self.repoSource("Sources/LogXCore/LiveStream.swift")
        let src = storeMain + storeLive
        XCTAssertFalse(src.contains("URLSession.shared"), src)
        XCTAssertFalse(pump.contains("URLSession.shared"), pump)
        XCTAssertTrue(src.contains("LiveStreamPump.run"), src)
        XCTAssertTrue(pump.contains("MonitorSessions.stream"), pump)
        XCTAssertTrue(src.contains("ReconnectBackoff"), src)
        XCTAssertTrue(src.contains("syncLiveStreams()"), src)
        XCTAssertTrue(src.contains("pollTask = Task { await pollLoop() }"), src)
        XCTAssertTrue(src.contains("if !serverOK"), src)
        XCTAssertFalse(src.contains("client.logs"), src)
        XCTAssertTrue(src.contains("toggleErrorsOnly"), src)
        XCTAssertTrue(src.contains("startGeneration"), src)
        XCTAssertTrue(src.contains("guard gen == startGeneration"), src)
        XCTAssertTrue(src.contains("func clearFilters()"), src)
    }

    func testEmptyFilterClearGoesThroughStore() throws {
        let empty = try Self.repoSource("Sources/LogX/Views/RequestEmptyView.swift")
        XCTAssertTrue(empty.contains("clearFilters()"), empty)
        XCTAssertFalse(empty.contains("errorsOnly = false"), empty)
    }

    func testLiveLogDecoderFillsEmptySerialAndRejectsGarbage() {
        let raw = #"{"key":"k1","value":{"method":"GET","url":"https://x.uz/a","responseCode":200,"source":"logcat"}}"#
        let log = LiveLogDecoder.decode(raw, serial: "USB-1")
        XCTAssertEqual(log?.key, "k1")
        XCTAssertEqual(log?.serial, "USB-1")
        XCTAssertEqual(log?.method, "GET")
        XCTAssertNil(LiveLogDecoder.decode("{", serial: "USB-1"))
        XCTAssertNil(LiveLogDecoder.decode("", serial: "USB-1"))

        let withSerial = #"{"key":"k2","value":{"method":"POST","url":"https://x.uz/b","serial":"KEEP","source":"logcat"}}"#
        XCTAssertEqual(LiveLogDecoder.decode(withSerial, serial: "USB-1")?.serial, "KEEP")
    }

    func testDeviceRailFavoritesGoesThroughStoreMethod() throws {
        let src = try Self.repoSource("Sources/LogX/Views/DeviceRail.swift")
        XCTAssertTrue(src.contains("toggleFavoritesOnly()"), src)
        XCTAssertFalse(src.contains("favoritesOnly.toggle()"), src)
        XCTAssertTrue(src.contains("Barcha ilovalar"), src)
    }

    func testRequestDetailRedactIsSingleToggle() throws {
        let src = try Self.repoSource("Sources/LogX/Views/RequestDetail.swift")
        XCTAssertFalse(src.contains("store.redactEnabled.toggle()"), src)
        XCTAssertTrue(src.contains("store.redactEnabled = $0"), src)
    }

    private static func repoSource(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }
}
