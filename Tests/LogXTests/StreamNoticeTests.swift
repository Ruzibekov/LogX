import XCTest
@testable import LogXCore

final class StreamNoticeTests: XCTestCase {
    private func text(_ raw: String) -> String? {
        StreamNoticeParser.notice(for: raw)?.text
    }

    func testLogcatEOFBecomesOneShortLine() {
        let raw = #"{"message":"logcat: Unexpected EOF!\n\nThis means that either the device shut down, logd crashed, or this instance of logcat was unable to read log\nmessages as quickly as they were being produced.\n\nIf you have enabled significant logging, look into using the -G option to increase log buffer sizes."}"#
        let notice = StreamNoticeParser.notice(for: raw)
        XCTAssertEqual(notice?.text, "Log oqimi uzildi (bufer to'lib ketdi) — qayta ulanyapti")
        XCTAssertEqual(notice?.severity, .transient)
        XCTAssertFalse(notice?.text.contains("\n") ?? true)
        XCTAssertFalse(notice?.text.contains("\\n") ?? true)
    }

    func testRawStderrWithoutJSONIsAlsoClassified() {
        XCTAssertEqual(text("logcat: Unexpected EOF!"), "Log oqimi uzildi (bufer to'lib ketdi) — qayta ulanyapti")
    }

    func testDeviceClassesAreActionable() {
        XCTAssertEqual(
            StreamNoticeParser.notice(for: #"{"message":"error: device unauthorized."}"#)?.severity,
            .actionable
        )
        XCTAssertEqual(text(#"{"message":"error: device offline"}"#), "Qurilma oflayn — kabelni qayta uling")
        XCTAssertEqual(text("adb: device 'R58N12ABC' not found"), "Qurilma topilmadi — USB kabelni tekshiring")
        XCTAssertEqual(text("error: no devices/emulators found"), "Qurilma topilmadi — USB kabelni tekshiring")
    }

    func testDaemonAndPipeDropsAreTransient() {
        XCTAssertEqual(text("write: Broken pipe"), "Oqim uzildi — qayta ulanyapti")
        XCTAssertEqual(text("adb: cannot connect to daemon at tcp:5037"), "adb bilan aloqa yo'q — qayta ulanyapti")
    }

    func testAdbNoiseIsNotShown() {
        XCTAssertNil(StreamNoticeParser.notice(for: "* daemon not running; starting now at tcp:5037"))
        XCTAssertNil(StreamNoticeParser.notice(for: "* daemon started successfully"))
        XCTAssertNil(StreamNoticeParser.notice(for: "--------- beginning of main"))
        XCTAssertNil(StreamNoticeParser.notice(for: #"{"message":"   "}"#))
        XCTAssertNil(StreamNoticeParser.notice(for: ""))
    }

    func testUnknownErrorIsCollapsedAndTruncated() {
        let long = String(repeating: "tushunarsiz xato ", count: 40)
        let out = text(#"{"message":"\#(long)"}"#)
        XCTAssertNotNil(out)
        XCTAssertLessThanOrEqual(out!.count, StreamNoticeParser.maxLength + 1)
        XCTAssertTrue(out!.hasSuffix("…"))
        XCTAssertFalse(out!.contains("  "))
    }

    func testShortUnknownErrorIsKeptAsIs() {
        XCTAssertEqual(text(#"{"message":"logcat: -G ignored"}"#), "logcat: -G ignored")
    }

    func testMultilinePlainTextCollapsesToOneLine() {
        let out = text("qator bir\n\tqator ikki\n\n qator uch ")
        XCTAssertEqual(out, "qator bir qator ikki qator uch")
    }
}
