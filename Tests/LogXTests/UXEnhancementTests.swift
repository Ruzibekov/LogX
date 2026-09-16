import XCTest
import AppKit
@testable import LogXCore
@testable import LogX

@MainActor
final class UXEnhancementTests: XCTestCase {
    private func makeStore() -> LogStore {
        let store = LogStore()
        store.hideNoise = false
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

    private func log(_ key: String, method: String = "GET", code: Int = 200, url: String, duration: Int = 100, ts: Double) -> NetworkLog {
        NetworkLog(
            key: key,
            method: method,
            url: url,
            responseCode: code,
            durationMs: duration,
            packageName: "uz.test.app",
            source: "logcat",
            serial: "A",
            ts: ts
        )
    }

    func testSmartQueryFilter() {
        let log1 = log("1", method: "POST", code: 200, url: "https://api.test.com/v1/auth/login", duration: 120, ts: 1000)
        var log2 = log("2", method: "GET", code: 500, url: "https://api.test.com/v1/users", duration: 450, ts: 2000)
        log2.error = "Internal server crash"

        // Status / Code
        XCTAssertTrue(LogFilter.matchesSmartQuery(log2, query: "status:500"))
        XCTAssertFalse(LogFilter.matchesSmartQuery(log1, query: "status:500"))
        XCTAssertTrue(LogFilter.matchesSmartQuery(log1, query: "code:200"))

        // Method
        XCTAssertTrue(LogFilter.matchesSmartQuery(log1, query: "method:POST"))
        XCTAssertTrue(LogFilter.matchesSmartQuery(log1, query: "m:POST"))
        XCTAssertFalse(LogFilter.matchesSmartQuery(log2, query: "method:POST"))

        // Host and Path
        XCTAssertTrue(LogFilter.matchesSmartQuery(log1, query: "host:api.test.com"))
        XCTAssertTrue(LogFilter.matchesSmartQuery(log1, query: "path:/v1/auth"))
        XCTAssertFalse(LogFilter.matchesSmartQuery(log2, query: "path:/v1/auth"))

        // Combined tokens and free text
        XCTAssertTrue(LogFilter.matchesSmartQuery(log2, query: "status:500 crash"))
        XCTAssertFalse(LogFilter.matchesSmartQuery(log2, query: "status:500 login"))
    }

    func testLogStoreSorting() {
        let store = makeStore()
        let logA = log("a", method: "GET", code: 200, url: "https://h.uz/alpha", duration: 100, ts: 1000)
        let logB = log("b", method: "POST", code: 500, url: "https://h.uz/beta", duration: 300, ts: 2000)
        let logC = log("c", method: "DELETE", code: 404, url: "https://h.uz/gamma", duration: 50, ts: 1500)

        store.ingestBatch([logA, logB, logC])

        // Default sort: time descending -> logB (2000), logC (1500), logA (1000)
        store.sortField = .time
        store.sortOrder = .descending
        store.recomputeDerivedState()
        XCTAssertEqual(store.visibleLogs.map(\.key), ["b", "c", "a"])

        // Time ascending -> logA, logC, logB
        store.toggleSort(.time)
        XCTAssertEqual(store.sortOrder, .ascending)
        XCTAssertEqual(store.visibleLogs.map(\.key), ["a", "c", "b"])

        // Duration descending -> logB (300), logA (100), logC (50)
        store.toggleSort(.duration)
        XCTAssertEqual(store.sortField, .duration)
        XCTAssertEqual(store.sortOrder, .descending)
        XCTAssertEqual(store.visibleLogs.map(\.key), ["b", "a", "c"])

        // Status code ascending -> logA (200), logC (404), logB (500)
        store.sortField = .status
        store.sortOrder = .ascending
        store.recomputeDerivedState()
        XCTAssertEqual(store.visibleLogs.map(\.key), ["a", "c", "b"])

        // Method ascending -> DELETE (C), GET (A), POST (B)
        store.sortField = .method
        store.sortOrder = .ascending
        store.recomputeDerivedState()
        XCTAssertEqual(store.visibleLogs.map(\.key), ["c", "a", "b"])
    }

    nonisolated func testCustomReplayRequestBuilder() throws {
        let url = URL(string: "https://example.com/api/test")!
        let headers = ["Authorization": "Bearer secret_token", "Content-Type": "application/json"]
        let body = "{\"name\":\"test\"}"

        let req = try Replay.request(method: "POST", url: url, headers: headers, body: body)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url, url)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer secret_token")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(req.httpBody, body.data(using: .utf8))
    }

    nonisolated func testHighlighterDynamicFontSize() {
        let text = "{\"status\": \"ok\"}"
        let attr1 = JSONHighlighter.nsAttributedString(for: text, fontSize: 11.5)
        let attr2 = JSONHighlighter.nsAttributedString(for: text, fontSize: 16.0)

        var range1 = NSRange(location: 0, length: 0)
        let font1 = attr1.text.attribute(.font, at: 0, effectiveRange: &range1) as? NSFont
        var range2 = NSRange(location: 0, length: 0)
        let font2 = attr2.text.attribute(.font, at: 0, effectiveRange: &range2) as? NSFont

        XCTAssertNotNil(font1)
        XCTAssertNotNil(font2)
        XCTAssertEqual(font1?.pointSize, 11.5)
        XCTAssertEqual(font2?.pointSize, 16.0)
    }

    nonisolated func testRenderedBodyKeyDefaultFontSize() {
        let key = RenderedBody.Key(logKey: "k", tab: .response, redact: false, pretty: true, query: "", index: 0, tree: false)
        XCTAssertEqual(key.fontSize, 11.5)

        let customKey = RenderedBody.Key(logKey: "k", tab: .response, redact: false, pretty: true, query: "", index: 0, tree: false, fontSize: 14.0)
        XCTAssertEqual(customKey.fontSize, 14.0)
    }
}
