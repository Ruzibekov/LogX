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

final class ThemeAndSelectionTests: XCTestCase {
    private func source(_ rel: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
    }

    func testListDoesNotUseNativeSelectionHighlight() throws {
        let list = try source("Sources/LogX/Views/RequestList.swift")
        XCTAssertFalse(list.contains("selection: Binding"), list)
        XCTAssertTrue(list.contains("listRowBackground(Color.clear)"), list)
        XCTAssertTrue(list.contains("onKeyPress(.upArrow)"), list)
        XCTAssertTrue(list.contains("onKeyPress(.downArrow)"), list)
        XCTAssertTrue(list.contains("proxy.scrollTo(key"), list)
        let row = try source("Sources/LogX/Views/RequestRow.swift")
        XCTAssertTrue(row.contains("onTapGesture { store.selectLog(log) }"), row)
        XCTAssertTrue(row.contains("LogXTheme.selection"), row)
    }

    func testMethodChipsAreMonochrome() throws {
        let theme = try source("Sources/LogX/Theme.swift")
        XCTAssertFalse(theme.contains("#A855F7"), theme)
        XCTAssertTrue(theme.contains("case \"DELETE\": return err"), theme)
        for f in ["Sources/LogX/Views/RequestRow.swift", "Sources/LogX/Views/DetailHeader.swift", "Sources/LogX/Views/RequestFilterBar.swift"] {
            let s = try source(f)
            XCTAssertFalse(s.contains("methodColor(log.method).opacity"), f)
            XCTAssertFalse(s.contains("methodColor(method)"), f)
        }
    }

    func testSingleAccentLanguageAcrossViews() throws {
        for f in ["RequestDetail", "DetailFindBar", "DeviceRail", "ContentView", "RequestFilterBar"] {
            let s = try source("Sources/LogX/Views/\(f).swift")
            XCTAssertFalse(s.contains("accent.opacity("), f)
            XCTAssertTrue(s.contains("LogXTheme.chipOn"), f)
        }
        for f in ["RequestRow", "RequestEmptyView", "DetailHeader"] {
            let s = try source("Sources/LogX/Views/\(f).swift")
            XCTAssertFalse(s.contains("accent.opacity("), f)
        }
        let share = try source("Sources/LogX/ShareCardRenderer.swift")
        XCTAssertFalse(share.contains("0.388, green: 0.400, blue: 0.945"), "share card must use the app palette")
        XCTAssertTrue(share.contains("0.357, green: 0.553, blue: 0.937"), share)
        let theme = try source("Sources/LogX/Theme.swift")
        XCTAssertTrue(theme.contains("case .redirect3xx: return text2"), "3xx must not borrow the interactive accent")
    }

    func testListKeyboardAndFollowScrollGuards() throws {
        let list = try source("Sources/LogX/Views/RequestList.swift")
        XCTAssertTrue(list.contains("onMoveCommand"), list)
        XCTAssertTrue(list.contains("guard !store.followLatest"), "follow mode must not scroll-jump on every batch")
        XCTAssertTrue(list.contains("listFocused = true"), list)
        let row = try source("Sources/LogX/Views/RequestRow.swift")
        XCTAssertTrue(row.contains(".isSelected"), row)
    }

    @MainActor
    func testMoveSelectionWalksVisibleListAndClamps() {
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
        store.ingestBatch((0..<3).map { i in
            NetworkLog(key: "k\(i)", method: "GET", url: "https://api.example.uz/p\(i)", responseCode: 200, packageName: "uz.test.app", source: "logcat", serial: "A", ts: 1_000 + Double(i))
        })
        XCTAssertEqual(store.visibleLogs.count, 3)
        XCTAssertNil(store.selectedKey)
        store.moveSelection(by: 1)
        XCTAssertEqual(store.selectedKey, store.visibleLogs[0].key)
        store.moveSelection(by: 1)
        XCTAssertEqual(store.selectedKey, store.visibleLogs[1].key)
        store.moveSelection(by: 5)
        XCTAssertEqual(store.selectedKey, store.visibleLogs[2].key)
        store.moveSelection(by: -10)
        XCTAssertEqual(store.selectedKey, store.visibleLogs[0].key)
        store.clearSelection()
        store.moveSelection(by: -1)
        XCTAssertEqual(store.selectedKey, store.visibleLogs[2].key, "↑ without selection starts from the bottom")
    }
}
