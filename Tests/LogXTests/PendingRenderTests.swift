import XCTest
import SwiftUI
import AppKit
import LogXCore
@testable import LogX

final class PendingClockTests: XCTestCase {
    func testElapsedLabelFormats() {
        let now = Date(timeIntervalSince1970: 1_789_000_100)
        XCTAssertEqual(PendingClock.label(ts: 1_789_000_099_200, now: now), "0.8 s")
        XCTAssertEqual(PendingClock.label(ts: 1_789_000_088, now: now), "12 s")
        XCTAssertEqual(PendingClock.label(ts: 1_789_000_000, now: now), "1m 40s")
        XCTAssertEqual(PendingClock.label(ts: nil, now: now), "…")
        XCTAssertEqual(PendingClock.label(ts: 1_789_000_200, now: now), "0.0 s", "clock skew never shows negative time")
    }

    func testPendingTurnsStaleWhenNoAnswerArrives() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let sentAt = now.timeIntervalSince1970 * 1000
        XCTAssertFalse(PendingClock.isStale(ts: sentAt - 30_000, now: now))
        XCTAssertTrue(PendingClock.isStale(ts: sentAt - PendingClock.staleAfter * 1000 - 1, now: now))
        XCTAssertFalse(PendingClock.isStale(ts: nil, now: now))
        XCTAssertEqual(PendingClock.title(ts: sentAt - 1000, now: now), "Kutilmoqda")
        XCTAssertEqual(PendingClock.title(ts: sentAt - 600_000, now: now), "Javob kelmadi")
    }

    func testTickerSlowsDownOnceRequestIsStale() {
        let start = Date(timeIntervalSince1970: 1_789_000_000)
        let sentAt = (start.timeIntervalSince1970 - PendingClock.staleAfter + 0.25) * 1000
        let schedule = PendingSchedule(ts: sentAt)
        let steps = Array(schedule.entries(from: start, mode: .normal).prefix(6))
        let gaps = zip(steps.dropFirst(), steps).map { ($0.timeIntervalSince($1) * 10).rounded() / 10 }
        XCTAssertEqual(gaps, [0.1, 0.1, 0.1, 1, 1])
        let unknown = Array(PendingSchedule(ts: nil).entries(from: start, mode: .normal).prefix(3))
        XCTAssertEqual(unknown[1].timeIntervalSince(unknown[0]), 1)
    }

    func testStatusCodeLabel() {
        XCTAssertEqual(NetworkLog(key: "p", isPending: true).statusCodeLabel, "···")
        XCTAssertEqual(NetworkLog(key: "n").statusCodeLabel, "NET")
        XCTAssertEqual(NetworkLog(key: "o", responseCode: 204).statusCodeLabel, "204")
    }

    func testRenderedBodyIsNotReusedAfterResponseArrives() {
        let waiting = RenderedBody.Key(logKey: "r", tab: .response, redact: false, pretty: true, query: "", index: 0, tree: false, pending: true)
        let answered = RenderedBody.Key(logKey: "r", tab: .response, redact: false, pretty: true, query: "", index: 0, tree: false, pending: false)
        XCTAssertNotEqual(waiting, answered)
        XCTAssertNotEqual(waiting.contentID, answered.contentID)
    }
}

@MainActor
final class PendingRenderTests: XCTestCase {
    private func store(_ logs: [NetworkLog], selected: String) -> LogStore {
        let s = LogStore()
        s.hideNoise = false
        s.followLatest = false
        s.slowOnly = false
        s.errorsOnly = false
        s.favoritesOnly = false
        s.status = .all
        s.selectedMethod = "ALL"
        s.selectedAppId = "all"
        s.selectedSerial = nil
        s.query = ""
        for log in logs { s.liveByKey[log.key] = log }
        s.rebuildFromLive()
        s.selectedKey = selected
        s.connection = .live
        s.isLoading = false
        return s
    }

    private func logs() -> [NetworkLog] {
        let now = Date().timeIntervalSince1970 * 1000
        var sent = NetworkLog(key: "p", method: "POST", url: "https://api.online-mahalla.uz/v3/appeal/create", ts: now - 2300, isPending: true)
        sent.source = "logcat"
        sent.requestBody = "{\"title\":\"Yo'l ta'miri\"}"
        var done = NetworkLog(key: "d", method: "GET", url: "https://api.online-mahalla.uz/v3/profile/me", responseCode: 200, durationMs: 84, ts: now - 5000)
        done.source = "logcat"
        done.responseBody = "{\"ok\":true}"
        return [sent, done]
    }

    private func snapshot<V: View>(_ view: V, size: CGSize, name: String) throws -> NSBitmapImageRep {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try png.write(to: dir.appendingPathComponent("\(name).png"))
        return rep
    }

    func testPendingRowRenders() throws {
        let items = logs()
        let s = store(items, selected: "p")
        let view = VStack(spacing: 0) {
            ForEach(items) { log in
                RequestRow(log: log, selected: log.key == "p", now: Date(), showAppColumn: false, showTimeColumn: true)
            }
        }
        .background(LogXTheme.bg)
        .environmentObject(s)
        let rep = try snapshot(view, size: CGSize(width: 460, height: 112), name: "render-pending-rows")
        XCTAssertEqual(rep.pixelsHigh, 224)
    }

    func testStalePendingRowRenders() throws {
        let old = Date().timeIntervalSince1970 * 1000 - 400_000
        let lost = NetworkLog(key: "s", method: "GET", url: "https://api.online-mahalla.uz/v3/news", ts: old, isPending: true)
        let s = store([lost], selected: "s")
        let row = RequestRow(log: lost, selected: true, now: Date(), showAppColumn: false, showTimeColumn: true)
            .background(LogXTheme.bg)
            .environmentObject(s)
        _ = try snapshot(row, size: CGSize(width: 460, height: 56), name: "render-pending-stale-row")
        s.detailTab = .response
        _ = try snapshot(RequestDetail().environmentObject(s), size: CGSize(width: 760, height: 400), name: "render-pending-stale-detail")
    }

    func testPendingDetailShowsWaitingResponse() throws {
        let s = store(logs(), selected: "p")
        s.detailTab = .response
        let rep = try snapshot(RequestDetail().environmentObject(s), size: CGSize(width: 760, height: 560), name: "render-pending-detail")
        XCTAssertGreaterThan(rep.pixelsWide, 0)
    }
}
