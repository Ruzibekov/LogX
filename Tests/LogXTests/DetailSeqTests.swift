import XCTest
@testable import LogXCore

final class DetailSeqTests: XCTestCase {
    func testNextTokenIsCurrent() {
        var seq = DetailSeq()
        let token = seq.next()
        XCTAssertEqual(token, 1)
        XCTAssertTrue(seq.isCurrent(token))
    }

    func testStaleTokenRejectedAfterNext() {
        var seq = DetailSeq()
        let first = seq.next()
        let second = seq.next()
        XCTAssertTrue(seq.isCurrent(second))
        XCTAssertFalse(seq.isCurrent(first))
        XCTAssertEqual(seq.value, 2)
    }

    func testUnusedTokenIsNotCurrentAfterBump() {
        var seq = DetailSeq()
        XCTAssertTrue(seq.isCurrent(0))
        _ = seq.next()
        XCTAssertFalse(seq.isCurrent(0))
        XCTAssertFalse(seq.isCurrent(99))
    }
}
