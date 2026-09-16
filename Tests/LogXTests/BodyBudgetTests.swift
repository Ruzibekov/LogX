import XCTest
@testable import LogXCore

final class BodyBudgetTests: XCTestCase {
    private func log(_ key: String, request: String?, response: String?) -> NetworkLog {
        var l = NetworkLog(key: key, method: "POST", url: "https://h/x", api: "/x", responseCode: 200, durationMs: 5, ts: 1)
        l.requestBody = request
        l.responseBody = response
        return l
    }

    func testShortBodyIsUntouched() {
        XCTAssertEqual(BodyBudget.clamp("{\"a\":1}"), "{\"a\":1}")
        XCTAssertNil(BodyBudget.clamp(nil))
    }

    func testLongBodyIsCutWithNotice() {
        let body = String(repeating: "x", count: 100)
        let out = BodyBudget.clamp(body, limit: 20)
        XCTAssertEqual(out, String(repeating: "x", count: 20) + BodyBudget.truncatedNotice)
    }

    func testCutNeverSplitsAMultibyteCharacter() {
        let body = String(repeating: "ў", count: 10) // har biri 2 bayt
        let out = BodyBudget.clamp(body, limit: 5)
        XCTAssertTrue(out?.hasPrefix("ўў") == true, out ?? "nil")
        XCTAssertFalse(out?.contains("\u{FFFD}") == true, out ?? "nil")
    }

    func testClampAppliesToBothBodies() {
        let out = BodyBudget.clamp(log("k", request: String(repeating: "a", count: 50), response: String(repeating: "b", count: 50)), limit: 10)
        XCTAssertTrue(out.requestBody?.hasSuffix(BodyBudget.truncatedNotice) == true)
        XCTAssertTrue(out.responseBody?.hasSuffix(BodyBudget.truncatedNotice) == true)
    }

    func testBytesCountsBothBodies() {
        XCTAssertEqual(BodyBudget.bytes(log("k", request: "abc", response: "de")), 5)
        XCTAssertEqual(BodyBudget.bytes(log("k", request: nil, response: nil)), 0)
    }

    func testOldestBodiesAreDroppedWhenBudgetIsExceeded() {
        let sizes = [(key: "new", bytes: 60), (key: "mid", bytes: 30), (key: "old", bytes: 30)]
        XCTAssertEqual(BodyBudget.keysToDrop(sizes: sizes, budget: 100), ["old"])
        XCTAssertEqual(BodyBudget.keysToDrop(sizes: sizes, budget: 200), [])
    }

    func testSelectedLogIsNeverDropped() {
        let sizes = [(key: "new", bytes: 90), (key: "selected", bytes: 40), (key: "old", bytes: 10)]
        let drop = BodyBudget.keysToDrop(sizes: sizes, budget: 100, protected: ["selected"])
        XCTAssertEqual(drop, ["old"])
    }

    func testEmptyBodiesAreNotCountedAsDroppable() {
        let sizes = [(key: "a", bytes: 0), (key: "b", bytes: 0)]
        XCTAssertEqual(BodyBudget.keysToDrop(sizes: sizes, budget: 0), [])
    }

    func testDropBodiesKeepsMetadataAndMarksTheReason() {
        let out = BodyBudget.dropBodies(log("k", request: "aaa", response: nil))
        XCTAssertEqual(out.requestBody, BodyBudget.droppedNotice)
        XCTAssertNil(out.responseBody)
        XCTAssertEqual(out.key, "k")
        XCTAssertEqual(out.responseCode, 200)
        XCTAssertTrue(BodyBudget.isDropped(out.requestBody))
    }
}
