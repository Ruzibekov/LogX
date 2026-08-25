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
        XCTAssertTrue(headers.contains("SO'ROV SARLAVHALARI"))
        XCTAssertTrue(headers.contains("Accept: application/json"))
        XCTAssertTrue(headers.contains("Server: nginx"))
        XCTAssertTrue(JSONFormat.body(for: log, tab: .request).contains("\"a\""))
        XCTAssertTrue(JSONFormat.body(for: log, tab: .response).contains("error"))
        let cap = JSONFormat.shareCaption(log: log, tab: .response)
        XCTAssertTrue(cap.contains("POST 400"))
        XCTAssertTrue(cap.contains("Javob"))
    }

    func testBodyRedactMasksHeadersAndBearer() {
        let log = NetworkLog(
            key: "sec",
            method: "GET",
            url: "https://x.uz/a",
            requestHeaders: ["Authorization": "Bearer secret-token", "Accept": "application/json"],
            requestBody: "Bearer secret-token rest",
            responseBody: #"{"ok":true}"#
        )
        let headers = JSONFormat.body(for: log, tab: .headers, redact: true)
        XCTAssertFalse(headers.contains("secret-token"), headers)
        XCTAssertTrue(headers.contains("••••••"), headers)
        XCTAssertTrue(headers.contains("Accept: application/json"), headers)
        let request = JSONFormat.body(for: log, tab: .request, redact: true)
        XCTAssertFalse(request.contains("secret-token"), request)
        XCTAssertTrue(JSONFormat.body(for: log, tab: .headers, redact: false).contains("secret-token"))
    }

    func testEmptyBody() {
        let log = NetworkLog(key: "e")
        XCTAssertEqual(JSONFormat.body(for: log, tab: .request), "")
        XCTAssertTrue(JSONFormat.body(for: log, tab: .headers).contains("—"))
    }

    func testPrettyFormattedPolygonAndLooseJSON() {
        let raw = #"{"error":null,"message":null,"timestamp":"yyyy-MM-dd hh:mm:ss","status":200,"polygon_str":{"type":"json","value":"{\"type\":\"MultiPolygon\",\"coordinates\":[[[64.59,40.02],[64.54,40.02]]]}"}}"#
        let pretty = JSONFormat.pretty(raw)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.contains("\"error\""))
        XCTAssertTrue(pretty.contains("\"polygon_str\""))
        XCTAssertTrue(pretty.hasPrefix("{\n"))
    }

    func testPrettyStringEncodedJSON() {
        let raw = "\"{\\\"status\\\":200,\\\"message\\\":\\\"ok\\\"}\""
        let pretty = JSONFormat.pretty(raw)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.contains("\"status\""))
        XCTAssertTrue(pretty.contains("200"))
    }

    func testFallbackTokenizerFormatsBrokenJSON() {
        let raw = "{status: 200, items: [1, 2, 3],}"
        let pretty = JSONFormat.pretty(raw)
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.contains("items:"))
    }

    func testLooseTextDecodesArbitraryJSONStructure() throws {
        let json = """
        {
            "responseBody": {
                "error": null,
                "data": [
                    {"id": 1, "name": "Item 1"},
                    {"id": 2, "name": "Item 2"}
                ]
            }
        }
        """
        struct TestContainer: Decodable {
            var responseBody: LooseText?
        }
        let decoded = try JSONDecoder().decode(TestContainer.self, from: json.data(using: .utf8)!)
        let text = decoded.responseBody?.text
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("Item 1"))
        XCTAssertTrue(text!.contains("Item 2"))
    }
}

final class HighlightHeadersTests: XCTestCase {
    func testSectionPlainKeyGreenValueBlue() {
        let text = "SO'ROV SARLAVHALARI\nAccept: application/json\nContent-Length: 524"
        let spans = JSONFormat.highlightHeaders(text)
        XCTAssertTrue(spans.contains { $0.kind == .plain && $0.text.contains("SARLAVHALARI") })
        XCTAssertTrue(spans.contains { $0.kind == .key && $0.text == "Accept" })
        XCTAssertTrue(spans.contains { $0.kind == .key && $0.text == "Content-Length" })
        XCTAssertTrue(spans.contains { $0.kind == .string && $0.text.hasPrefix(" application/json") })
        XCTAssertTrue(spans.contains { $0.kind == .string && $0.text == " 524" })
    }

    func testNoTrailingNewlineSpan() {
        let spans = JSONFormat.highlightHeaders("Accept: application/json")
        XCTAssertNotEqual(spans.last?.text, "\n")
        XCTAssertTrue(JSONFormat.highlightHeaders("").isEmpty)
    }
}
