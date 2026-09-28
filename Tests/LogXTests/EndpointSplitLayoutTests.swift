import XCTest
@testable import LogX

final class EndpointSplitLayoutTests: XCTestCase {
    private let layout = EndpointSplitLayout()

    func testEverythingFitsKeepsIdealWidths() {
        let split = layout.widths(available: 500, path: 300, query: 100)
        XCTAssertEqual(split.path, 300)
        XCTAssertEqual(split.query, 100)
    }

    func testLongPathStillLeavesRoomForQueryEnd() {
        let split = layout.widths(available: 400, path: 600, query: 300)
        XCTAssertEqual(split.query, 180)
        XCTAssertEqual(split.path, 220)
    }

    func testShortQueryShownInFull() {
        let split = layout.widths(available: 400, path: 600, query: 60)
        XCTAssertEqual(split.query, 60)
        XCTAssertEqual(split.path, 340)
    }

    func testShortPathGivesQueryTheRest() {
        let split = layout.widths(available: 400, path: 100, query: 900)
        XCTAssertEqual(split.path, 100)
        XCTAssertEqual(split.query, 300)
    }
}
