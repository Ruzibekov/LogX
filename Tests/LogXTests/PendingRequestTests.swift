import XCTest
import LogXCore
@testable import LogX

final class PendingRequestDecodeTests: XCTestCase {
    private func envelope(pending: Bool, code: Int?) -> String {
        let status = code.map(String.init) ?? "null"
        return """
        {"key":"lc|1|2|t|POST|https://api.example.uz/v1/slow","value":{"method":"POST","url":"https://api.example.uz/v1/slow","responseCode":\(status),"requestBody":"{\\"a\\":1}","_slim":false,"_pending":\(pending)}}
        """
    }

    func testPendingEventDecodesAsPendingNotNetworkError() throws {
        let log = try XCTUnwrap(LiveLogDecoder.decode(envelope(pending: true, code: nil), serial: "A"))
        XCTAssertTrue(log.isPending)
        XCTAssertEqual(log.statusClass, .pending)
        XCTAssertFalse(log.statusClass.isFailure)
        XCTAssertEqual(log.statusDescription, "Kutilmoqda")
        XCTAssertEqual(log.requestBody, "{\"a\":1}")
    }

    func testFinalEventIsNotPending() throws {
        let log = try XCTUnwrap(LiveLogDecoder.decode(envelope(pending: false, code: 200), serial: "A"))
        XCTAssertFalse(log.isPending)
        XCTAssertEqual(log.statusClass, .ok2xx)
    }

    func testMissingPendingFlagMeansAnswered() throws {
        let raw = #"{"key":"k","value":{"method":"GET","url":"https://api.example.uz/v1","responseCode":null}}"#
        let log = try XCTUnwrap(LiveLogDecoder.decode(raw, serial: "A"))
        XCTAssertFalse(log.isPending)
        XCTAssertEqual(log.statusClass, .net)
    }
}

@MainActor
final class PendingRequestStoreTests: XCTestCase {
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

    private func log(_ key: String, code: Int? = nil, pending: Bool, ts: Double) -> NetworkLog {
        NetworkLog(
            key: key,
            method: "POST",
            url: "https://api.example.uz/v1/slow",
            responseCode: code,
            durationMs: code == nil ? nil : 1200,
            packageName: "uz.test.app",
            source: "logcat",
            serial: "A",
            ts: ts,
            isPending: pending
        )
    }

    func testPendingRowAppearsImmediatelyAndIsReplacedByResponse() {
        let store = makeStore()
        store.followLatest = true
        store.ingestBatch([log("r", pending: true, ts: 1)])
        XCTAssertEqual(store.visibleLogs.map(\.key), ["r"])
        XCTAssertEqual(store.visibleLogs.first?.isPending, true)
        XCTAssertEqual(store.selectedKey, "r", "follow-latest picks the request as soon as it is sent")

        store.ingestBatch([log("r", code: 200, pending: false, ts: 9)])
        XCTAssertEqual(store.visibleLogs.count, 1, "response replaces the pending row, no duplicate")
        let answered = store.visibleLogs.first
        XCTAssertEqual(answered?.isPending, false)
        XCTAssertEqual(answered?.responseCode, 200)
        XCTAssertEqual(answered?.ts, 1, "row keeps the time the request was sent")
        XCTAssertEqual(store.selectedLog?.responseCode, 200)
    }

    func testReplayedPendingNeverRevertsAnsweredRow() {
        let store = makeStore()
        store.ingestBatch([log("r", code: 200, pending: false, ts: 1)])
        store.ingestBatch([log("r", pending: true, ts: 5)])
        XCTAssertEqual(store.visibleLogs.first?.isPending, false)
        XCTAssertEqual(store.visibleLogs.first?.responseCode, 200)
    }

    func testPendingIsNotCountedAsError() {
        let store = makeStore()
        store.ingestBatch([log("r", pending: true, ts: 1)])
        XCTAssertEqual(store.errorCount, 0)
        store.status = .net
        store.recomputeDerivedState()
        XCTAssertTrue(store.visibleLogs.isEmpty, "NET filter shows failed requests only")
        store.status = .all
        store.errorsOnly = true
        store.recomputeDerivedState()
        XCTAssertTrue(store.visibleLogs.isEmpty)
    }

    func testEventsOfOneRequestCountOnceForUnknownAppStreak() {
        let store = makeStore()
        func unknown(_ key: String, pending: Bool) -> NetworkLog {
            NetworkLog(key: key, method: "GET", url: "https://api.example.uz/v1", responseCode: pending ? nil : 200, serial: "S", ts: 1, isPending: pending)
        }
        for index in 0..<(LogStore.unknownStreakLimit - 1) {
            let key = "u\(index)"
            store.noteUnknownApps(serial: "S", items: [unknown(key, pending: true), unknown(key, pending: false)])
            store.noteUnknownApps(serial: "S", items: [unknown(key, pending: false)])
        }
        XCTAssertEqual(store.unknownAppStreak["S"], LogStore.unknownStreakLimit - 1)
        XCTAssertNil(store.lastUnknownReopen["S"], "pending and repeated answers of one request must not trigger a stream reopen")
        store.noteUnknownApps(serial: "S", items: [unknown("last", pending: false)])
        XCTAssertNotNil(store.lastUnknownReopen["S"])
    }

    func testPausedBufferKeepsOnlyLatestStateOfARequest() {
        let store = makeStore()
        store.togglePause()
        store.ingestBatch([log("r", pending: true, ts: 1)])
        store.ingestBatch([log("r", code: 200, pending: false, ts: 9)])
        store.togglePause()
        XCTAssertEqual(store.visibleLogs.count, 1)
        XCTAssertEqual(store.visibleLogs.first?.isPending, false)
    }
}
