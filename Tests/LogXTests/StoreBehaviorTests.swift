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
        XCTAssertFalse(share.contains("srgbRed:"), "share card must use the app palette")
        XCTAssertTrue(share.contains("NSColor(rgbHex: 0x1FB6D4)"), share)
        let theme = try source("Sources/LogX/Theme.swift")
        XCTAssertTrue(theme.contains("case .redirect3xx: return text2"), "3xx must not borrow the interactive accent")
    }

    func testListKeyboardAndFollowScrollGuards() throws {
        let list = try source("Sources/LogX/Views/RequestList.swift")
        XCTAssertTrue(list.contains("onMoveCommand"), list)
        XCTAssertTrue(list.contains("anchor: store.followLatest ? .top : .center"), "follow mode pins the newest row at the top; manual selection stays centered")
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

@MainActor
final class ConvenienceTests: XCTestCase {
    private func source(_ rel: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
    }

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

    private func log(_ key: String, code: Int? = 200, path: String = "/v1/items", ts: Double) -> NetworkLog {
        NetworkLog(key: key, method: "GET", url: "https://api.example.uz\(path)", responseCode: code, packageName: "uz.test.app", source: "logcat", serial: "A", ts: ts)
    }

    func testNextAndPreviousErrorWalkFailuresAndWrap() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1), log("b", code: 500, ts: 2), log("c", ts: 3), log("d", code: nil, ts: 4), log("e", ts: 5)])
        let keys = store.visibleLogs.map(\.key)
        XCTAssertEqual(keys, ["e", "d", "c", "b", "a"])
        XCTAssertTrue(store.moveToError(forward: true))
        XCTAssertEqual(store.selectedKey, "d")
        XCTAssertTrue(store.moveToError(forward: true))
        XCTAssertEqual(store.selectedKey, "b")
        XCTAssertTrue(store.moveToError(forward: true), "wraps to the first failure")
        XCTAssertEqual(store.selectedKey, "d")
        XCTAssertTrue(store.moveToError(forward: false))
        XCTAssertEqual(store.selectedKey, "b")
        XCTAssertTrue(store.moveToError(forward: false))
        XCTAssertEqual(store.selectedKey, "d")
        store.selectLog(store.visibleLogs[0])
        XCTAssertTrue(store.moveToError(forward: false), "backward from the first row must wrap, not trap")
        XCTAssertEqual(store.selectedKey, "b")
        store.clearSelection()
        XCTAssertTrue(store.moveToError(forward: false), "backward with no selection starts from the bottom")
        XCTAssertEqual(store.selectedKey, "b")
        store.selectLog(store.visibleLogs[4])
        XCTAssertTrue(store.moveToError(forward: true), "forward from the last row wraps")
        XCTAssertEqual(store.selectedKey, "d")
    }

    func testNextErrorWithoutFailuresLeavesSelectionAndSaysSo() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1), log("b", ts: 2)])
        store.selectLog(log("a", ts: 1))
        XCTAssertFalse(store.moveToError(forward: true))
        XCTAssertEqual(store.selectedKey, "a")
        XCTAssertEqual(store.toast?.text, "Keyingi xato yo'q")
    }

    func testCopyOfEmptyTextIsRefusedWithFeedback() {
        let store = makeStore()
        store.copy("   \n", what: "javob")
        XCTAssertEqual(store.toast?.text, "javob bo'sh — nusxalanmadi")
        store.copy("—", what: "URL")
        XCTAssertEqual(store.toast?.text, "URL bo'sh — nusxalanmadi")
    }

    func testClearOffersUndoInToastAndUndoRestores() {
        let store = makeStore()
        store.ingestBatch([log("a", ts: 1), log("b", ts: 2)])
        store.clearLogs()
        XCTAssertEqual(store.allLogs.count, 0)
        XCTAssertEqual(store.toast?.text, "2 ta so'rov tozalandi")
        XCTAssertEqual(store.toast?.actionTitle, "Bekor qilish")
        store.toast?.action?()
        XCTAssertEqual(store.allLogs.count, 2)
    }

    func testEndpointFilterTogglesQueryToPathOnly() {
        let store = makeStore()
        let item = log("a", path: "/v1/items?page=2", ts: 1)
        store.ingestBatch([item, log("b", path: "/v1/other", ts: 2)])
        store.filterEndpoint(item)
        XCTAssertEqual(store.query, "/v1/items")
        store.filterEndpoint(item)
        XCTAssertEqual(store.query, "")
    }

    func testSelectingRowWhileFollowingExplainsWhyFollowStopped() {
        let store = makeStore()
        store.followLatest = true
        store.ingestBatch([log("a", ts: 1)])
        store.selectLog(log("a", ts: 1))
        XCTAssertFalse(store.followLatest)
        XCTAssertEqual(store.toast?.text, "Kuzat o'chdi — ⌘L qaytaradi")
    }

    func testTransientFiltersAreNotRestoredOnLaunch() throws {
        let store = try source("Sources/LogX/Store.swift")
        XCTAssertFalse(store.contains("status = StatusClass(rawValue: prefs.status)"), "status filter must start fresh")
        XCTAssertFalse(store.contains("errorsOnly = prefs.errorsOnly"), store)
        XCTAssertFalse(store.contains("selectedMethod = prefs.selectedMethod"), store)
        XCTAssertFalse(store.contains("slowOnly = prefs.slowOnly"), store)
        let detail = try source("Sources/LogX/Views/RequestDetail.swift")
        XCTAssertFalse(detail.contains("CopyBox.plainText("), "every copy in the detail goes through store.copy")
        XCTAssertTrue(store.contains("hideNoise = prefs.hideNoise"), store)
        XCTAssertTrue(store.contains("selectedSerial = prefs.selectedSerial"), store)
    }

    func testFindQuerySurvivesSelectionChange() throws {
        let detail = try source("Sources/LogX/Views/RequestDetail.swift")
        let onChange = detail.range(of: ".onChange(of: store.selectedKey)")!
        let block = detail[onChange.lowerBound..<detail.index(onChange.upperBound, offsetBy: 80)]
        XCTAssertFalse(block.contains("findQuery = \"\""), String(block))
        XCTAssertTrue(block.contains("findIndex = 0"), String(block))
    }

    func testAffordancesAreVisible() throws {
        let app = try source("Sources/LogX/LogXApp.swift")
        XCTAssertTrue(app.contains("\"Keyingi xato\", #selector(nextError(_:)), \"e\", .command"), app)
        XCTAssertTrue(app.contains("Ko'rinadiganlarni HAR saqlash"), app)
        let content = try source("Sources/LogX/Views/ContentView.swift")
        XCTAssertFalse(content.contains("onExitCommand"), "Esc must not clear selection from anywhere in the window")
        let list = try source("Sources/LogX/Views/RequestList.swift")
        XCTAssertTrue(list.contains("noticeStrip(banner)"), list)
        XCTAssertTrue(list.contains("ToastView(toast: toast)"), list)
        XCTAssertTrue(list.contains("Shu endpointni filtrlash"), list)
        XCTAssertTrue(list.contains("Faqat shu host"), list)
        XCTAssertFalse(list.contains("raw.isEmpty ? \"—\""), "empty copy must not write a dash")
        XCTAssertFalse(list.contains("CopyBox.plainText(store"), "list copies go through store.copy for feedback")
        let row = try source("Sources/LogX/Views/RequestRow.swift")
        XCTAssertTrue(row.contains(".help(store.shareableURL(log))"), row)
        XCTAssertTrue(row.contains(".help(log.statusDescription)"), row)
        XCTAssertTrue(row.contains("store.filterEndpoint(log)"), row)
        let header = try source("Sources/LogX/Views/DetailHeader.swift")
        XCTAssertTrue(header.contains("RelativeTime.stamp(ts: log.ts)"), header)
        XCTAssertTrue(header.contains(".disabled(masked)"), header)
        let detail = try source("Sources/LogX/Views/RequestDetail.swift")
        XCTAssertTrue(detail.contains("Tokenlarni yashir"), detail)
        let filters = try source("Sources/LogX/Views/RequestFilterBar.swift")
        XCTAssertTrue(filters.contains("LogXNotice.focusList"), "↓ from search must hand focus to the list")
        let empty = try source("Sources/LogX/Views/RequestEmptyView.swift")
        XCTAssertTrue(empty.contains("adb devices"), empty)
    }

    func testStampShowsDateAndMilliseconds() {
        let ts = 1_756_800_000_123.0
        XCTAssertEqual(RelativeTime.stamp(ts: ts, timeZone: TimeZone(identifier: "UTC")!), "02.09 08:00:00.123")
        XCTAssertEqual(RelativeTime.stamp(ts: nil), "—")
        XCTAssertTrue(StatusClass.err5xx.isFailure)
        XCTAssertTrue(StatusClass.net.isFailure)
        XCTAssertFalse(StatusClass.ok2xx.isFailure)
    }
}
