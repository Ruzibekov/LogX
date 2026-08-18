import XCTest
@testable import LogXCore

final class JSONFormatTests: XCTestCase {
    func testPrettySortsKeys() {
        let raw = #"{"z":1,"a":{"b":true}}"#
        let pretty = JSONFormat.pretty(raw)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.hasPrefix("{"))
        let aIdx = pretty.range(of: "\"a\"")?.lowerBound
        let zIdx = pretty.range(of: "\"z\"")?.lowerBound
        XCTAssertNotNil(aIdx)
        XCTAssertNotNil(zIdx)
        XCTAssertTrue(aIdx! < zIdx!)
    }

    func testPrettyPassthroughInvalid() {
        XCTAssertEqual(JSONFormat.pretty("not-json"), "not-json")
        XCTAssertEqual(JSONFormat.pretty("   "), "")
    }

    func testHighlightKinds() {
        let pretty = JSONFormat.pretty(#"{"ok":true,"n":2,"s":"x","z":null}"#)
        let spans = JSONFormat.highlight(pretty)
        let kinds = Set(spans.map(\.kind))
        XCTAssertTrue(kinds.contains(.key))
        XCTAssertTrue(kinds.contains(.string))
        XCTAssertTrue(kinds.contains(.number))
        XCTAssertTrue(kinds.contains(.boolNull))
        XCTAssertTrue(kinds.contains(.punct))
        XCTAssertFalse(spans.contains { $0.kind == .key && $0.text.contains("true") })
    }

    func testHeadersAndShareCaption() {
        let log = NetworkLog(
            key: "k",
            method: "POST",
            url: "https://api.example/x",
            responseCode: 400,
            requestHeaders: ["Accept": "application/json"],
            responseHeaders: ["Server": "nginx"],
            requestBody: #"{"a":1}"#,
            responseBody: #"{"error":"no"}"#
        )
        let headers = JSONFormat.body(for: log, tab: .headers)
        XCTAssertTrue(headers.contains("REQUEST"))
        XCTAssertTrue(headers.contains("Accept: application/json"))
        XCTAssertTrue(headers.contains("Server: nginx"))
        XCTAssertTrue(JSONFormat.body(for: log, tab: .request).contains("\"a\""))
        XCTAssertTrue(JSONFormat.body(for: log, tab: .response).contains("error"))
        let cap = JSONFormat.shareCaption(log: log, tab: .response)
        XCTAssertTrue(cap.contains("POST 400"))
        XCTAssertTrue(cap.contains("Response"))
    }

    func testEmptyBody() {
        let log = NetworkLog(key: "e")
        XCTAssertEqual(JSONFormat.body(for: log, tab: .request), "")
        XCTAssertTrue(JSONFormat.body(for: log, tab: .headers).contains("—"))
    }
}
