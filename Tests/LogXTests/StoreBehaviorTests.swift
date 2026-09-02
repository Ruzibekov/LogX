import XCTest
import LogXCore
@testable import LogX

@MainActor
final class StoreBehaviorTests: XCTestCase {
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
        return store
    }

    private func log(_ key: String, code: Int = 200, url: String = "https://api.example.uz/v1/items", ts: Double) -> NetworkLog {
        NetworkLog(key: key, method: "GET", url: url, responseCode: code, packageName: "uz.test.app", source: "logcat", serial: "A", ts: ts)
    }

    func testSelectedLogNeverFallsBackToAnotherRow() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1), log("b", ts: 2)])
        XCTAssertNil(store.selectedLog)
        store.selectedKey = "ghost"
        XCTAssertNil(store.selectedLog)
        store.selectLog(log("a", ts: 1))
        XCTAssertEqual(store.selectedLog?.key, "a")
        store.clearSelection()
        XCTAssertNil(store.selectedKey)
        XCTAssertNil(store.selectedLog)
    }

    func testIngestDoesNotSelectHiddenLogAndFollowHonorsFilters() {
        let store = makeStore()
        store.followLatest = true
        store.ingestBatch([log("ok", ts: 1)])
        XCTAssertEqual(store.selectedKey, "ok")
        store.toggleErrorsOnly()
        XCTAssertEqual(store.selectedKey, "ok", "filter change keeps the selection, marked hidden")
        XCTAssertTrue(store.selectedIsHidden)
        store.ingestBatch([log("ok2", ts: 2)])
        XCTAssertEqual(store.selectedKey, "ok", "200 OK hidden by errors-only must not be selected")
        store.ingestBatch([log("err", code: 500, ts: 3), log("noise", code: 500, url: "https://analytics.example.com/hit", ts: 4)])
        XCTAssertEqual(store.selectedKey, "err", "noise row is hidden and must not win follow-latest")
    }

    func testSelectionLeavesRowThatBecomesHidden() {
        let store = makeStore()
        store.ingestBatch([log("ok", ts: 1), log("err", code: 500, ts: 2)])
        store.selectLog(log("ok", ts: 1))
        store.toggleErrorsOnly()
        XCTAssertEqual(store.selectedLog?.key, "ok", "selection does not jump to another row")
        XCTAssertTrue(store.selectedIsHidden)
        XCTAssertEqual(store.visibleLogs.map(\.key), ["err"])
    }

    func testPauseBuffersAndResumeFlushes() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1)])
        store.togglePause()
        store.ingestBatch([log("b", ts: 2), log("c", ts: 3)])
        XCTAssertEqual(store.pendingWhilePausedCount, 2)
        XCTAssertEqual(store.allLogs.count, 1)
        XCTAssertEqual(store.lastActivityTs, 1, "paused rows do not move the activity clock")
        store.togglePause()
        XCTAssertEqual(store.pendingWhilePausedCount, 0)
        XCTAssertEqual(store.allLogs.count, 3)
        XCTAssertEqual(store.lastActivityTs, 3)
    }

    func testNoiseCountsAndExportGuard() {
        let store = makeStore()
        XCTAssertFalse(store.canExport)
        store.ingestBatch([log("n", url: "https://crashlytics.example.com/x", ts: 1)])
        XCTAssertEqual(store.scopedLogCount, 1)
        XCTAssertEqual(store.noiseHiddenCount, 1)
        XCTAssertTrue(store.visibleLogs.isEmpty)
        XCTAssertFalse(store.canExport, "export covers visible rows only")
        store.toggleHideNoise()
        XCTAssertEqual(store.visibleLogs.count, 1)
        XCTAssertTrue(store.canExport)
        store.clearLogs()
        XCTAssertFalse(store.canExport)
        XCTAssertNil(store.lastActivityTs)
        XCTAssertEqual(store.scopedLogCount, 0)
    }

    func testQueryIsDebouncedThenApplied() async throws {
        let store = makeStore()
        store.ingestBatch([log("a", url: "https://api.example.uz/v1/alpha", ts: 1), log("b", url: "https://api.example.uz/v1/beta", ts: 2)])
        store.applyQuery("beta")
        XCTAssertEqual(store.query, "beta")
        XCTAssertEqual(store.visibleLogs.count, 2, "heavy filter waits for the debounce window")
        try await Task.sleep(nanoseconds: UInt64((LogStore.queryDebounce + 0.2) * 1_000_000_000))
        XCTAssertEqual(store.visibleLogs.map(\.key), ["b"])
        store.applyQuery("")
        XCTAssertEqual(store.visibleLogs.count, 2, "empty query applies immediately")
    }

    func testShareableURLAndBodyCopyHonorRedact() {
        let store = makeStore()
        let item = log("t", url: "https://api.example.uz/v1/x?token=secret1&p=1", ts: 1)
        store.redactEnabled = true
        XCTAssertFalse(store.shareableURL(item).contains("secret1"))
        store.redactEnabled = false
        XCTAssertTrue(store.shareableURL(item).contains("secret1"))
    }

    func testFavoriteCountTracksLiveLogsOnly() {
        let store = makeStore()
        store.favoriteKeys = ["stale"]
        store.ingestBatch([log("a", ts: 1)])
        XCTAssertEqual(store.liveFavoriteCount, 0)
        store.toggleFavorite("a")
        XCTAssertEqual(store.liveFavoriteCount, 1)
        XCTAssertTrue(store.isFavorite("a"))
        XCTAssertFalse(store.favoriteKeys.contains("a"), "favorites are stored hashed")
    }
}
