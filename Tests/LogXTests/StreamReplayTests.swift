import XCTest
import LogXCore
@testable import LogX

final class StreamReplayURLTests: XCTestCase {
    private let base = URL(string: "http://127.0.0.1:8787")!

    func testFirstConnectHasTailWithoutSince() {
        let raw = LiveStreamURL.httpStream(base: base, serial: "S1", tail: 80)!.absoluteString
        XCTAssertTrue(raw.contains("tail=80"), raw)
        XCTAssertFalse(raw.contains("since="), raw)
    }

    func testSinceIsAppendedAsEpochMillis() {
        let raw = LiveStreamURL.httpStream(base: base, serial: "192.168.0.131:5555", tail: 80, sinceMs: 1_792_394_316_443)!.absoluteString
        XCTAssertTrue(raw.contains("tail=80"), raw)
        XCTAssertTrue(raw.hasSuffix("&since=1792394316443"), raw)
    }

    func testNonPositiveSinceIsDropped() {
        XCTAssertFalse(LiveStreamURL.httpStream(base: base, serial: "S1", sinceMs: 0)!.absoluteString.contains("since="))
        XCTAssertFalse(LiveStreamURL.httpStream(base: base, serial: "S1", sinceMs: -5)!.absoluteString.contains("since="))
    }

    func testWindowUsesNewestLogMinusLookback() {
        let now = 1_792_394_400_000.0
        XCTAssertEqual(StreamReplayWindow.sinceMs(newestLogMs: now - 30_000, openedAtMs: now - 80_000, nowMs: now), Int64(now - 40_000))
    }

    func testWindowFallsBackToOpenedAt() {
        let now = 1_792_394_400_000.0
        XCTAssertEqual(StreamReplayWindow.sinceMs(newestLogMs: nil, openedAtMs: now - 78_000, nowMs: now), Int64(now - 88_000))
    }

    func testWindowPrefersLaterOfOpenedAndNewest() {
        let now = 1_792_394_400_000.0
        XCTAssertEqual(StreamReplayWindow.sinceMs(newestLogMs: now - 600_000, openedAtMs: now - 78_000, nowMs: now), Int64(now - 88_000))
    }

    func testWindowClampedToServerMaxAge() {
        let now = 1_792_394_400_000.0
        XCTAssertEqual(StreamReplayWindow.sinceMs(newestLogMs: now - 3_600_000, openedAtMs: nil, nowMs: now), Int64(now - StreamReplayWindow.maxAgeMs))
    }

    func testWindowFutureAnchorClampedToNow() {
        let now = 1_792_394_400_000.0
        XCTAssertEqual(StreamReplayWindow.sinceMs(newestLogMs: now + 90_000, openedAtMs: nil, nowMs: now), Int64(now - StreamReplayWindow.lookbackMs))
    }

    func testWindowEmptyOrInvalidReturnsNil() {
        XCTAssertNil(StreamReplayWindow.sinceMs(newestLogMs: nil, openedAtMs: nil, nowMs: 1_792_394_400_000))
        XCTAssertNil(StreamReplayWindow.sinceMs(newestLogMs: .nan, openedAtMs: 0, nowMs: 1_792_394_400_000))
    }
}

@MainActor
final class StreamReplayStoreTests: XCTestCase {
    private func makeStore() -> LogStore {
        let store = LogStore()
        store.hideNoise = false
        store.followLatest = false
        store.slowOnly = false
        store.errorsOnly = false
        store.favoritesOnly = false
        store.status = .all
        store.selectedMethod = "ALL"
        store.selectedAppId = "all"
        store.selectedSerial = nil
        store.query = ""
        store.isPaused = false
        return store
    }

    private func log(_ key: String, ts: Double?, pending: Bool = false) -> NetworkLog {
        NetworkLog(key: key, method: "GET", url: "https://api.example.uz/v1/items", responseCode: pending ? nil : 200, packageName: "uz.test.app", source: "logcat", serial: "A", ts: ts, isPending: pending)
    }

    func testReplayDuplicateKeepsOneRowAndEarliestTs() {
        let store = makeStore()
        store.ingestBatch([log("lc|1|2|10-19 12:00:00.000|GET|u", ts: 1_792_394_500_000)])
        store.ingestBatch([log("lc|1|2|10-19 12:00:00.000|GET|u", ts: 1_792_394_400_000)])
        XCTAssertEqual(store.logCount, 1)
        XCTAssertEqual(store.liveByKey["lc|1|2|10-19 12:00:00.000|GET|u"]?.ts, 1_792_394_400_000)
        store.ingestBatch([log("lc|1|2|10-19 12:00:00.000|GET|u", ts: 1_792_394_600_000)])
        XCTAssertEqual(store.logCount, 1)
        XCTAssertEqual(store.liveByKey["lc|1|2|10-19 12:00:00.000|GET|u"]?.ts, 1_792_394_400_000)
    }

    func testReplayPendingThenDoneKeepsOneRow() {
        let store = makeStore()
        store.ingestBatch([log("k", ts: 1_792_394_400_000, pending: true)])
        store.ingestBatch([log("k", ts: 1_792_394_400_000)])
        XCTAssertEqual(store.logCount, 1)
        XCTAssertEqual(store.liveByKey["k"]?.isPending, false)
        store.ingestBatch([log("k", ts: 1_792_394_400_000, pending: true)])
        XCTAssertEqual(store.liveByKey["k"]?.isPending, false)
    }

    func testReplayKeepsExistingTsWhenIncomingMissing() {
        let store = makeStore()
        store.ingestBatch([log("k", ts: 1_792_394_400_000)])
        var again = log("k", ts: nil)
        again.durationMs = 9
        store.ingestBatch([again])
        XCTAssertEqual(store.liveByKey["k"]?.ts, 1_792_394_400_000)
    }

    func testPausedReplayDedupesWithEarliestTs() {
        let store = makeStore()
        store.isPaused = true
        store.ingestBatch([log("k", ts: 1_792_394_500_000)])
        store.ingestBatch([log("k", ts: 1_792_394_400_000)])
        XCTAssertEqual(store.pendingWhilePausedCount, 1)
        store.togglePause()
        XCTAssertEqual(store.logCount, 1)
        XCTAssertEqual(store.liveByKey["k"]?.ts, 1_792_394_400_000)
    }

    func testFirstConnectHasNoSinceAndReconnectReplaysFromNewest() {
        let store = makeStore()
        let now = Date(timeIntervalSince1970: 1_792_394_400)
        XCTAssertNil(store.replaySinceMs(serial: "A", now: now))
        store.streamOpenedAtMs["A"] = 1_792_394_322_000
        XCTAssertEqual(store.replaySinceMs(serial: "A", now: now), 1_792_394_312_000)
        store.noteNewestLog(serial: "A", items: [log("x", ts: 1_792_394_390_000), log("y", ts: 1_792_394_350_000), log("z", ts: nil)])
        XCTAssertEqual(store.replaySinceMs(serial: "A", now: now), 1_792_394_380_000)
        store.noteNewestLog(serial: "A", items: [log("old", ts: 1_792_394_000_000)])
        XCTAssertEqual(store.newestLogTsBySerial["A"], 1_792_394_390_000)
        XCTAssertNil(store.replaySinceMs(serial: "B", now: now))
    }
}
