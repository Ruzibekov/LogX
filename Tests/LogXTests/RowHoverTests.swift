import XCTest
@testable import LogX

@MainActor
final class RowHoverTests: XCTestCase {
    func testLeavingAnotherRowKeepsTheNewHover() {
        let hover = RowHover()
        hover.update("b", inside: true)
        hover.update("a", inside: false)
        XCTAssertEqual(hover.key, "b")
    }

    func testLeavingTheHoveredRowClearsIt() {
        let hover = RowHover()
        hover.update("a", inside: true)
        hover.update("a", inside: false)
        XCTAssertNil(hover.key)
    }

    func testDisappearingHoveredRowReleasesItsKey() {
        let hover = RowHover()
        hover.update("a", inside: true)
        hover.release("a")
        XCTAssertNil(hover.key)
        hover.update("b", inside: true)
        hover.release("a")
        XCTAssertEqual(hover.key, "b")
    }

    func testRowReleasesHoverWhenItDisappears() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/LogX/Views/RequestRow.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("rowHover.release(log.key)"))
    }
}
