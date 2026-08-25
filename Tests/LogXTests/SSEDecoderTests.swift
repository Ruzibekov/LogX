import XCTest
@testable import LogXCore

final class SSEDecoderTests: XCTestCase {
    private func feedAll(_ decoder: inout SSEDecoder, _ text: String) -> [SSEEvent] {
        var out: [SSEEvent] = []
        // "\r\n" Swift'da bitta grapheme — shu sababli oddiy split("\n") yetmaydi.
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" }).map(String.init) {
            if let hit = decoder.feed(line: line) { out.append(hit) }
        }
        return out
    }

    func testBasicEventFlushesOnEmptyLine() {
        var sse = SSEDecoder()
        let events = feedAll(&sse, "event: meta\ndata: {\"a\":1}\n\nevent: http\ndata: {\"b\":2}\n\n")
        XCTAssertEqual(events, [
            SSEEvent(event: "meta", data: "{\"a\":1}"),
            SSEEvent(event: "http", data: "{\"b\":2}"),
        ])
    }

    func testKeepaliveCommentDoesNotBreakEvent() {
        var sse = SSEDecoder()
        let events = feedAll(&sse, "event: http\ndata: {\"x\":9}\n\n: ping 123\n\n")
        XCTAssertEqual(events, [SSEEvent(event: "http", data: "{\"x\":9}")])
    }

    func testCRLFLineEndings() {
        var sse = SSEDecoder()
        let events = feedAll(&sse, "event: http\r\ndata: {\"k\":1}\r\n\r\n")
        XCTAssertEqual(events, [SSEEvent(event: "http", data: "{\"k\":1}")])
    }

    func testMultiLineDataJoinedWithNewline() {
        var sse = SSEDecoder()
        let events = feedAll(&sse, "event: http\ndata: line1\ndata: line2\n\n")
        XCTAssertEqual(events, [SSEEvent(event: "http", data: "line1\nline2")])
    }

    func testNoSpaceAfterColon() {
        var sse = SSEDecoder()
        let events = feedAll(&sse, "event:http\ndata:{\"n\":1}\n\n")
        XCTAssertEqual(events, [SSEEvent(event: "http", data: "{\"n\":1}")])
    }

    func testEmptyLineWithoutDataEmitsNothing() {
        var sse = SSEDecoder()
        XCTAssertNil(sse.feed(line: ""))
        XCTAssertNil(sse.feed(line: "\r"))
        XCTAssertEqual(feedAll(&sse, "event: end\n\n"), [])
    }

    func testIncompleteEventNotFlushedEarly() {
        var sse = SSEDecoder()
        let events = feedAll(&sse, "event: http\ndata: {\"partial\":")
        XCTAssertEqual(events, [])
    }

    func testMonitorServerShape() {
        var sse = SSEDecoder()
        let text = """
        event: meta
        data: {"serial":"10AC8Z1QNJ000T6","ts":1787192839971,"kind":"http","pids":{"17613":"uz.realsoft.onlinemahalla.assistant"}}

        event: http
        data: {"key":"lc|1|GET|https://api.example.uz/v1/x","value":{"method":"GET","url":"https://api.example.uz/v1/x","responseCode":200,"source":"logcat"}}

        : ping 1787193065209

        """
        let events = feedAll(&sse, text + "\n")
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].event, "meta")
        XCTAssertEqual(events[1].event, "http")
        XCTAssertTrue(events[1].data.contains("responseCode"))
    }
}
