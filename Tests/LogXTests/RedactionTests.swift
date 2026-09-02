import XCTest
@testable import LogXCore

final class RedactionTests: XCTestCase {
    private let ph = Redactor.placeholder

    private func sample() -> NetworkLog {
        NetworkLog(
            key: "r1",
            method: "POST",
            url: "https://api.example.uz/v1/login?token=abc123&page=2&pinfl=12345678901234#top",
            responseCode: 200,
            packageName: "uz.test.app",
            source: "logcat",
            serial: "A",
            requestHeaders: ["Authorization": "Bearer aaa.bbb", "Accept": "application/json"],
            requestBody: #"{"password":"qwerty","user":"ali","nested":{"access_token":"t1"}}"#,
            responseBody: #"{"token":"zzz","items":[{"pinfl":"12345678901234","name":"Vali"}]}"#
        )
    }

    func testMaskTextMasksEveryBearerOccurrence() {
        let text = "Authorization: Bearer one\nX: bearer two, tail"
        let masked = Redactor.maskText(text) ?? ""
        XCTAssertFalse(masked.contains("one"), masked)
        XCTAssertFalse(masked.contains("two"), masked)
        XCTAssertEqual(masked.components(separatedBy: ph).count - 1, 2, masked)
        XCTAssertTrue(masked.hasSuffix(", tail"), masked)
    }

    func testMaskURLMasksOnlySensitiveQueryValues() {
        let masked = Redactor.maskURL(sample().url)
        XCTAssertEqual(masked, "https://api.example.uz/v1/login?token=\(ph)&page=2&pinfl=\(ph)#top")
        XCTAssertEqual(Redactor.maskURL("https://a.uz/x"), "https://a.uz/x")
    }

    func testMaskParamsKeepsOrderAndMasksSensitive() {
        let masked = Redactor.maskParams(sample().queryParams)
        XCTAssertEqual(masked.map(\.key), ["token", "page", "pinfl"])
        XCTAssertEqual(masked.map(\.value), [ph, "2", ph])
    }

    func testBodyRedactsJSONKeysInResponseAndRequest() {
        let log = sample()
        let response = JSONFormat.body(for: log, tab: .response, redact: true)
        XCTAssertFalse(response.contains("zzz"), response)
        XCTAssertFalse(response.contains("12345678901234"), response)
        XCTAssertTrue(response.contains("Vali"), response)

        let request = JSONFormat.body(for: log, tab: .request, redact: true)
        XCTAssertFalse(request.contains("qwerty"), request)
        XCTAssertFalse(request.contains("\"t1\""), request)
        XCTAssertTrue(request.contains("ali"), request)

        let plain = JSONFormat.body(for: log, tab: .response, redact: false)
        XCTAssertTrue(plain.contains("zzz"), plain)
    }

    func testBodyParamsTabHonorsRedact() {
        let log = sample()
        let masked = JSONFormat.body(for: log, tab: .params, redact: true)
        XCTAssertTrue(masked.contains("token: \(ph)"), masked)
        XCTAssertTrue(masked.contains("page: 2"), masked)
        let open = JSONFormat.body(for: log, tab: .params, redact: false)
        XCTAssertTrue(open.contains("token: abc123"), open)
    }

    func testResponseBodyFallsBackToErrorWhenEmpty() {
        var log = sample()
        log.responseBody = "  "
        log.error = "ECONNRESET"
        XCTAssertEqual(JSONFormat.body(for: log, tab: .response, redact: false), "ECONNRESET")
    }

    func testCurlRedactsURLHeadersAndBody() {
        let curl = CurlBuilder.command(for: sample(), redact: true)
        XCTAssertFalse(curl.contains("abc123"), curl)
        XCTAssertFalse(curl.contains("aaa.bbb"), curl)
        XCTAssertFalse(curl.contains("qwerty"), curl)
        XCTAssertTrue(curl.contains("page=2"), curl)
        let open = CurlBuilder.command(for: sample(), redact: false)
        XCTAssertTrue(open.contains("abc123"), open)
        XCTAssertTrue(open.contains("qwerty"), open)
    }

    func testExportsRedactURLAndQuery() throws {
        let log = sample()
        let json = String(decoding: SessionExport.json(logs: [log], redact: true), as: UTF8.self)
        XCTAssertFalse(json.contains("abc123"), json)
        XCTAssertFalse(json.contains("zzz"), json)
        XCTAssertTrue(json.contains("page=2"), json)

        let har = try XCTUnwrap(try JSONSerialization.jsonObject(with: SessionExport.har(logs: [log], redact: true)) as? [String: Any])
        let entries = try XCTUnwrap(((har["log"] as? [String: Any])?["entries"]) as? [[String: Any]])
        let request = try XCTUnwrap(entries.first?["request"] as? [String: Any])
        let url = try XCTUnwrap(request["url"] as? String)
        XCTAssertFalse(url.contains("abc123"), url)
        let query = try XCTUnwrap(request["queryString"] as? [[String: String]])
        XCTAssertEqual(query.first(where: { $0["name"] == "token" })?["value"], ph)
        XCTAssertEqual(query.first(where: { $0["name"] == "page" })?["value"], "2")
    }
}
