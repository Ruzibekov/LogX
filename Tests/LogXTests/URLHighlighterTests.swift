import XCTest
@testable import LogXCore

final class URLHighlighterTests: XCTestCase {
    func testTokenizeFullURLWithQueryParams() {
        let url = "https://api.online-mahalla.uz/api/v1/business_survey/mobile?district_id=301076&obl_id=3"
        let spans = URLHighlighter.tokenize(url)

        XCTAssertFalse(spans.isEmpty)
        XCTAssertEqual(spans[0], URLSpan("https://", .scheme))
        XCTAssertEqual(spans[1], URLSpan("api.online-mahalla.uz", .host))
        XCTAssertEqual(spans[2], URLSpan("/api/v1/", .pathPrefix))
        XCTAssertEqual(spans[3], URLSpan("business_survey/mobile", .pathEndpoint))
        XCTAssertEqual(spans[4], URLSpan("?", .queryMark))
        XCTAssertEqual(spans[5], URLSpan("district_id", .paramKey))
        XCTAssertEqual(spans[6], URLSpan("=", .paramEquals))
        XCTAssertEqual(spans[7], URLSpan("301076", .paramValue))
        XCTAssertEqual(spans[8], URLSpan("&", .paramAmp))
        XCTAssertEqual(spans[9], URLSpan("obl_id", .paramKey))
        XCTAssertEqual(spans[10], URLSpan("=", .paramEquals))
        XCTAssertEqual(spans[11], URLSpan("3", .paramValue))
    }

    func testTokenizeURLWithPort() {
        let url = "http://127.0.0.1:8787/api/devices"
        let spans = URLHighlighter.tokenize(url)

        XCTAssertEqual(spans[0], URLSpan("http://", .scheme))
        XCTAssertEqual(spans[1], URLSpan("127.0.0.1", .host))
        XCTAssertEqual(spans[2], URLSpan(":8787", .port))
        XCTAssertEqual(spans[3], URLSpan("/api/", .pathPrefix))
        XCTAssertEqual(spans[4], URLSpan("devices", .pathEndpoint))
    }

    func testTokenizeRelativePath() {
        let path = "/api/v1/business_survey/mobile?id=123"
        let spans = URLHighlighter.tokenize(path)

        XCTAssertEqual(spans[0], URLSpan("/api/v1/", .pathPrefix))
        XCTAssertEqual(spans[1], URLSpan("business_survey/mobile", .pathEndpoint))
        XCTAssertEqual(spans[2], URLSpan("?", .queryMark))
        XCTAssertEqual(spans[3], URLSpan("id", .paramKey))
        XCTAssertEqual(spans[4], URLSpan("=", .paramEquals))
        XCTAssertEqual(spans[5], URLSpan("123", .paramValue))
    }

    func testTokenizeSingleSegmentPath() {
        let path = "/health"
        let spans = URLHighlighter.tokenize(path)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0], URLSpan("/health", .pathEndpoint))
    }

    func testTokenizeEmptyAndPlain() {
        XCTAssertTrue(URLHighlighter.tokenize("").isEmpty)
        let plain = URLHighlighter.tokenize("unknown-string")
        XCTAssertEqual(plain.count, 1)
        XCTAssertEqual(plain[0].kind, .pathEndpoint)
    }

    func testAttributedProducesNonEmptyString() {
        let attr = URLHighlighter.attributed("https://example.com/api/test?x=1", baseFontSize: 12)
        XCTAssertFalse(attr.characters.isEmpty)
        XCTAssertEqual(String(attr.characters), "https://example.com/api/test?x=1")
    }

    func testTokenizeFragment() {
        let url = "https://example.com/docs#intro"
        let spans = URLHighlighter.tokenize(url)
        XCTAssertTrue(spans.contains(where: { $0.kind == .fragment && $0.text == "#intro" }))
    }
}
