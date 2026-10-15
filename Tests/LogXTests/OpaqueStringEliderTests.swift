import XCTest
@testable import LogXCore

final class OpaqueStringEliderTests: XCTestCase {
    func testLongBase64ValueCollapsesToOneLineWithEllipsis() {
        let photo = String(repeating: "QUJDRA", count: 400)
        let json = "{\n  \"photo_base64\": \"\(photo)\",\n  \"sort_order\": 0\n}"
        let out = OpaqueStringElider.elide(json)
        XCTAssertTrue(out.contains("\"photo_base64\": \"\(photo.prefix(OpaqueStringElider.keep))…\","))
        XCTAssertTrue(out.contains("\"sort_order\": 0"))
        XCTAssertLessThan(out.count, 200)
    }

    func testShortAndSpacedStringsStayIntact() {
        let message = String(repeating: "xato yuz berdi ", count: 30)
        let json = "{\"session_id\": \"3ab1f741-28d2\", \"message\": \"\(message)\"}"
        XCTAssertEqual(OpaqueStringElider.elide(json), json)
    }

    func testCutDoesNotSplitEscapeSequence() {
        let value = String(repeating: "a", count: OpaqueStringElider.keep - 1) + "\\/" + String(repeating: "b", count: 300)
        let out = OpaqueStringElider.elide("{\"k\": \"\(value)\"}")
        XCTAssertFalse(out.contains("\\…"))
        XCTAssertTrue(out.hasSuffix("…\"}"))
    }

    func testEscapedQuotesInsideValueKeepStructure() {
        let value = String(repeating: "Z", count: 300) + "\\\"" + "tail"
        let out = OpaqueStringElider.elide("{\"k\": \"\(value)\", \"n\": 1}")
        XCTAssertTrue(out.hasSuffix("…\", \"n\": 1}"))
    }
}
