import AppKit
import XCTest
@testable import LogX
@testable import LogXCore

final class HighlightRunsTests: XCTestCase {
    private let sample = "{\"ok\":true,\"page\":2,\"items\":[{\"id\":7,\"name\":\"Aziza — Тошкент\",\"tags\":null}],\"note\":\"a:b, c\"}"

    func testRunsCoverEveryCharacter() {
        let runs = JSONFormat.highlightRuns(sample)
        XCTAssertFalse(runs.isEmpty)
        XCTAssertEqual(runs.reduce(0) { $0 + $1.length }, sample.utf16.count)
        XCTAssertFalse(runs.contains { $0.length <= 0 })
    }

    func testSpansRebuildTheOriginalText() {
        let spans = JSONFormat.highlight(sample)
        XCTAssertEqual(spans.map(\.text).joined(), sample)
        XCTAssertTrue(spans.contains { $0.kind == .key && $0.text.contains("items") })
        XCTAssertTrue(spans.contains { $0.kind == .number && $0.text == "2" })
        XCTAssertTrue(spans.contains { $0.kind == .boolNull && $0.text == "null" })
    }

    func testAdjacentPlainRunsAreMerged() {
        let runs = JSONFormat.highlightRuns("  \t  ")
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.kind, .plain)
    }

    func testHeaderRunsCoverEveryCharacter() {
        let text = "SO'ROV SARLAVHALARI\nAccept: application/json\n\nJAVOB SARLAVHALARI\nServer: nginx"
        let runs = JSONFormat.highlightHeaderRuns(text)
        XCTAssertEqual(runs.reduce(0) { $0 + $1.length }, text.utf16.count)
    }

    func testAttributedStringKeepsTheTextAndColours() {
        let rendered = JSONHighlighter.nsAttributedString(for: sample)
        XCTAssertEqual(rendered.text.string, sample)
        var coloured = 0
        rendered.text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: rendered.text.length)) { value, _, _ in
            if value != nil { coloured += 1 }
        }
        XCTAssertGreaterThan(coloured, 3, "rang oralig'i qo'yilmadi")
    }

    func testMultibyteTextIsNotShifted() {
        let text = "{\"joy\":\"Тошкент шаҳар\",\"n\":5}"
        let rendered = JSONHighlighter.nsAttributedString(for: text)
        XCTAssertEqual(rendered.text.string, text)
        let runs = JSONFormat.highlightRuns(text)
        XCTAssertEqual(runs.reduce(0) { $0 + $1.length }, text.utf16.count)
    }

    func testFindHighlightRangeIsMarked() {
        let matches = JSONFind.matches(sample, query: "Aziza")
        XCTAssertFalse(matches.isEmpty)
        let rendered = JSONHighlighter.nsAttributedString(for: sample, highlights: matches, activeIndex: 0)
        XCTAssertNotNil(rendered.activeRange)
    }
}

@MainActor
final class PublishedCountersTests: XCTestCase {
    private func log(_ index: Int) -> NetworkLog {
        NetworkLog(key: "k\(index)", method: "GET", url: "https://api.example.uz/v1/x/\(index)", serial: "S1", ts: Double(1_700_000_000 + index))
    }

    func testLogCountTracksTheList() {
        let store = LogStore()
        XCTAssertEqual(store.logCount, 0)
        store.ingestBatch((0..<12).map(log))
        XCTAssertEqual(store.logCount, store.allLogs.count)
        XCTAssertEqual(store.logCount, 12)
        store.clearLogs()
        XCTAssertEqual(store.logCount, 0)
    }

    func testPausedCountTracksTheBuffer() {
        let store = LogStore()
        store.isPaused = true
        store.ingestBatch((0..<5).map(log))
        XCTAssertEqual(store.pausedCount, 5)
        XCTAssertEqual(store.pendingWhilePausedCount, 5)
        store.togglePause()
        XCTAssertEqual(store.pausedCount, 0)
        XCTAssertEqual(store.logCount, 5)
    }

    func testClearResetsPausedCount() {
        let store = LogStore()
        store.isPaused = true
        store.ingestBatch((0..<3).map(log))
        store.clearLogs()
        XCTAssertEqual(store.pausedCount, 0)
        XCTAssertEqual(store.pendingWhilePausedCount, 0)
    }
}
