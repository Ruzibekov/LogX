import XCTest
import LogXCore
@testable import LogX

@MainActor
final class ReviewRegressionStoreTests: XCTestCase {
    private func makeStore() -> LogStore {
        let store = LogStore()
        store.hideNoise = true
        store.followLatest = false
        store.slowOnly = false
        store.errorsOnly = false
        store.favoritesOnly = false
        store.favoriteKeys = []
        store.status = .all
        store.selectedMethod = "ALL"
        store.selectedAppId = "all"
        store.selectedSerial = nil
        store.selectedHost = nil
        store.query = ""
        store.isPaused = false
        store.redactEnabled = false
        return store
    }

    private func log(_ key: String, code: Int? = 200, url: String = "https://api.example.uz/v1/items", ts: Double, pkg: String = "uz.test.app") -> NetworkLog {
        NetworkLog(key: key, method: "GET", url: url, responseCode: code, packageName: pkg, source: "logcat", serial: "A", ts: ts)
    }

    func testDisplayPathAndShareCardMaskQueryWhenRedactOn() {
        let store = makeStore()
        let item = log("t", url: "https://api.example.uz/v1/x?token=secret1&p=1", ts: 1)
        store.redactEnabled = true
        XCTAssertFalse(store.displayPath(item).contains("secret1"))
        XCTAssertTrue(store.displayPath(item).contains("p=1"))
        XCTAssertFalse(ShareCardRenderer.headerMeta(item, redact: true).contains("secret1"))
        XCTAssertTrue(ShareCardRenderer.headerMeta(item, redact: false).contains("secret1"))
        store.redactEnabled = false
        XCTAssertTrue(store.displayPath(item).contains("secret1"))
    }

    func testDuplicateKeyKeepsOriginalTimestampAndRefreshesRow() {
        let store = makeStore()
        store.ingestBatch([log("a", code: nil, ts: 10)])
        store.ingestBatch([log("a", code: 200, ts: 99)])
        XCTAssertEqual(store.allLogs.first?.ts, 10)
        XCTAssertEqual(store.allLogs.first?.responseCode, 200, "updated row must be re-rendered")
        XCTAssertEqual(store.lastActivityTs, 10, "replayed key must not move the activity clock")
    }

    func testClearWatermarkBlocksReplayUntilUndo() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1), log("b", ts: 2)])
        store.clearLogs()
        XCTAssertTrue(store.allLogs.isEmpty)
        XCTAssertTrue(store.canUndoClear)
        store.ingestBatch([log("a", ts: 1), log("c", ts: 3)])
        XCTAssertEqual(store.allLogs.map(\.key), ["c"], "server tail replay of cleared keys stays hidden")
        store.undoClear()
        XCTAssertFalse(store.canUndoClear)
        XCTAssertEqual(Set(store.allLogs.map(\.key)), ["a", "b", "c"])
        store.ingestBatch([log("b", ts: 2)])
        XCTAssertEqual(store.allLogs.count, 3)
    }

    func testPausedBufferDropsClearedKeysAndClearEmptiesBuffer() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1)])
        store.clearLogs()
        store.togglePause()
        store.ingestBatch([log("a", ts: 1), log("b", ts: 2)])
        XCTAssertEqual(store.pendingWhilePausedCount, 1)
        store.clearLogs()
        XCTAssertEqual(store.pendingWhilePausedCount, 0)
        store.togglePause()
        XCTAssertTrue(store.allLogs.isEmpty)
    }

    func testSelectionStaysOnHiddenRowInsteadOfJumping() {
        let store = makeStore()
        store.ingestBatch([log("ok", ts: 1), log("err", code: 500, ts: 2)])
        store.selectLog(log("ok", ts: 1))
        XCTAssertFalse(store.selectedIsHidden)
        store.toggleErrorsOnly()
        XCTAssertEqual(store.selectedKey, "ok", "filter change must not silently move selection")
        XCTAssertTrue(store.selectedIsHidden)
        XCTAssertEqual(store.selectedLog?.key, "ok")
        store.toggleErrorsOnly()
        XCTAssertFalse(store.selectedIsHidden)
    }

    func testUnknownAppStreakReopensStreamOnceAndThrottles() {
        let store = makeStore()
        let unknown = (0..<LogStore.unknownStreakLimit).map { log("u\($0)", ts: Double($0), pkg: "") }
        store.noteUnknownApps(serial: "S", items: Array(unknown.dropLast()))
        XCTAssertNil(store.lastUnknownReopen["S"])
        store.noteUnknownApps(serial: "S", items: [unknown.last!])
        XCTAssertNotNil(store.lastUnknownReopen["S"])
        XCTAssertEqual(store.unknownAppStreak["S"], 0)
        let first = store.lastUnknownReopen["S"]
        store.noteUnknownApps(serial: "S", items: unknown)
        XCTAssertEqual(store.lastUnknownReopen["S"], first, "second reopen within throttle window is skipped")
        store.noteUnknownApps(serial: "S", items: [log("known", ts: 9)])
        XCTAssertEqual(store.unknownAppStreak["S"], 0)
    }

    func testServerDownNeedsTwoConsecutiveFailures() async {
        let store = makeStore()
        store.client = MonitorClient(baseURL: URL(string: "http://127.0.0.1:9/")!)
        store.serverOK = true
        store.banner = "Stream: pid map failed"
        await store.refresh()
        XCTAssertTrue(store.serverOK, "one failed poll is not an outage")
        XCTAssertEqual(store.refreshFailures, 1)
        XCTAssertTrue(store.bannerIsStreamNotice)
        await store.refresh()
        XCTAssertFalse(store.serverOK)
        XCTAssertNotNil(store.banner)
        XCTAssertFalse(store.bannerIsStreamNotice)
    }

    func testFavoritesPersistAsHashesAndFilter() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1), log("b", ts: 2)])
        store.toggleFavorite("a")
        XCTAssertTrue(store.favoriteKeys.contains(FavoriteKey.hash("a")))
        store.toggleFavoritesOnly()
        XCTAssertEqual(store.visibleLogs.map(\.key), ["a"])
        store.toggleFavorite("a")
        XCTAssertFalse(store.isFavorite("a"))
        XCTAssertTrue(store.visibleLogs.isEmpty)
    }

    func testStreamErrorBannerClearsWhenLogsFlowAgain() {
        let store = makeStore()
        store.handleStreamChunk(serial: "S", chunk: .serverError("pid map failed"))
        XCTAssertEqual(store.banner, "Stream: pid map failed")
        XCTAssertTrue(store.bannerIsStreamNotice)
        store.handleStreamChunk(serial: "S", chunk: .logs([log("a", ts: 1)]))
        XCTAssertNil(store.banner)
        XCTAssertEqual(store.allLogs.count, 1)
    }

    func testPausedBufferIsCappedAtCapacity() {
        let store = makeStore()
        store.togglePause()
        let flood = (0..<(store.maxLogCapacity + 10)).map { log("p\($0)", ts: Double($0)) }
        store.ingestBatch(flood)
        XCTAssertEqual(store.pendingWhilePausedCount, store.maxLogCapacity)
        XCTAssertEqual(store.pendingWhilePaused.first?.key, "p10", "oldest overflow is dropped first")
    }

    func testClearDuringPauseKeepsWatermarkAndBufferedKeys() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1)])
        store.clearLogs()
        store.togglePause()
        store.ingestBatch([log("b", ts: 2)])
        store.clearLogs()
        store.togglePause()
        store.ingestBatch([log("a", ts: 1), log("b", ts: 2), log("c", ts: 3)])
        XCTAssertEqual(store.allLogs.map(\.key), ["c"], "both cleared keys stay blocked after replay")
        store.undoClear()
        XCTAssertEqual(Set(store.allLogs.map(\.key)), ["a", "b", "c"])
    }

    func testUpdatedLogInvalidatesQueryCache() async throws {
        let store = makeStore()
        store.ingestBatch([log("a", code: nil, ts: 1)])
        store.applyQuery("needle")
        try await Task.sleep(nanoseconds: UInt64((LogStore.queryDebounce + 0.2) * 1_000_000_000))
        XCTAssertTrue(store.visibleLogs.isEmpty)
        var full = log("a", code: 200, ts: 1)
        full.responseBody = "{\"m\":\"needle\"}"
        store.ingestBatch([full])
        XCTAssertEqual(store.visibleLogs.map(\.key), ["a"], "slim→full update must re-run the body search")
    }

    func testFollowLatestClearsSelectionWhenRowEvicted() {
        let store = makeStore()
        store.followLatest = true
        store.errorsOnly = true
        store.ingestBatch([log("first", code: 500, ts: 0)])
        XCTAssertEqual(store.selectedKey, "first")
        let flood = (1...(store.maxLogCapacity + 5)).map { log("ok\($0)", ts: Double($0)) }
        store.ingestBatch(flood)
        XCTAssertNil(store.selectedKey, "evicted row must not stay selected")
        XCTAssertFalse(store.selectedIsHidden)
    }
}
