import XCTest
@testable import LogXCore

final class ReviewRegressionCoreTests: XCTestCase {
    func testRedactorTokenMatchingAvoidsSubstringFalsePositives() {
        XCTAssertFalse(Redactor.isSensitive("passenger"))
        XCTAssertFalse(Redactor.isSensitive("Accept"))
        XCTAssertTrue(Redactor.isSensitive("userPassword"))
        XCTAssertTrue(Redactor.isSensitive("api_key"))
        XCTAssertTrue(Redactor.isSensitive("X-Auth-Token"))
        XCTAssertTrue(Redactor.isSensitive("cardNumber"))
        XCTAssertTrue(Redactor.isSensitive("Set-Cookie"))
    }

    func testRedactorMasksFormBodyAndJWT() {
        let form = Redactor.redactBody("username=ali&password=secret1&page=2")
        XCTAssertEqual(form, "username=ali&password=\(Redactor.placeholder)&page=2")
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc123DEF"
        let masked = Redactor.maskText("token \(jwt) end") ?? ""
        XCTAssertFalse(masked.contains(jwt), masked)
        XCTAssertTrue(masked.contains(Redactor.placeholder), masked)
        XCTAssertEqual(Redactor.maskText("Basic dXNlcjpwYXNz rest"), "Basic \(Redactor.placeholder) rest")
    }

    func testRedactBodyPreservesFormattingAndNestedJSON() {
        let raw = "{\n  \"password\": \"abc\",\n  \"name\": \"ok\"\n}"
        let out = Redactor.redactBody(raw, preserveFormat: true) ?? ""
        XCTAssertTrue(out.contains("\n  \"name\": \"ok\""), out)
        XCTAssertFalse(out.contains("abc"), out)
        let nested = #"{"payload":"{\"token\":\"t1\",\"n\":1}"}"#
        let nestedOut = Redactor.redactBody(nested) ?? ""
        XCTAssertFalse(nestedOut.contains("t1"), nestedOut)
        let rawNested = Redactor.redactBody(nested, preserveFormat: true) ?? ""
        XCTAssertFalse(rawNested.contains("t1"), rawNested)
        XCTAssertTrue(rawNested.contains("\\\"n\\\":1"), rawNested)
    }

    func testRawMaskKeepsJSONValidForObjectValues() throws {
        let raw = "{\"credentials\": {\"user\":\"a\",\"password\":\"b\"}, \"x\": [1, {\"token\":\"z\"}], \"y\": true}"
        let out = Redactor.maskRawJSONText(raw)
        let data = try XCTUnwrap(out.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["credentials"] as? String, Redactor.placeholder)
        XCTAssertEqual(obj["y"] as? Bool, true)
        let arr = try XCTUnwrap(obj["x"] as? [Any])
        XCTAssertEqual((arr[1] as? [String: Any])?["token"] as? String, Redactor.placeholder)
        XCTAssertFalse(out.contains("\"b\""), out)
    }

    func testBasicSchemeOnlyMasksBase64Tokens() {
        XCTAssertEqual(Redactor.maskText("{\"plan\":\"basic monthly\"}"), "{\"plan\":\"basic monthly\"}")
        XCTAssertEqual(Redactor.maskText("Basic dXNlcjpwYXNzd29yZA=="), "Basic \(Redactor.placeholder)")
        XCTAssertTrue(Redactor.isSensitive("password2"))
        XCTAssertTrue(Redactor.isSensitive("cvv2"))
    }

    func testMaskURLKeepsNonSensitiveQuery() {
        let url = Redactor.maskURL("https://a.uz/x?token=abc&page=3")
        XCTAssertFalse(url.contains("abc"), url)
        XCTAssertTrue(url.contains("page=3"), url)
    }

    func testCurlDropsTransportHeadersAndAddsCompressed() {
        let log = NetworkLog(
            key: "c", method: "POST", url: "https://a.uz/x",
            requestHeaders: [
                "Content-Length": "12", "Accept-Encoding": "gzip", "Host": "a.uz",
                "Connection": "keep-alive", "Content-Type": "application/json",
            ],
            requestBody: "{\"a\":1}"
        )
        let cmd = CurlBuilder.command(for: log)
        XCTAssertFalse(cmd.contains("Content-Length"), cmd)
        XCTAssertFalse(cmd.contains("Host:"), cmd)
        XCTAssertFalse(cmd.contains("Connection:"), cmd)
        XCTAssertFalse(cmd.contains("Accept-Encoding"), cmd)
        XCTAssertTrue(cmd.contains("--compressed"), cmd)
        XCTAssertTrue(cmd.contains("Content-Type: application/json"), cmd)
        XCTAssertTrue(cmd.contains("--data-binary"), cmd)
    }

    func testCurlSkipsOkHttpOmittedBody() {
        let log = NetworkLog(key: "o", method: "POST", url: "https://a.uz/x", requestBody: "(binary 1024-byte body omitted)")
        XCTAssertFalse(CurlBuilder.command(for: log).contains("--data-binary"))
    }

    func testNoiseMatchesPathSegmentsExactly() {
        XCTAssertFalse(LogNoise.isNoise(NetworkLog(key: "r", url: "https://api.uz/report/analytics-summary")))
        XCTAssertTrue(LogNoise.isNoise(NetworkLog(key: "a", url: "https://api.uz/analytics/x")))
        XCTAssertTrue(LogNoise.isNoise(NetworkLog(key: "h", url: "https://api.uz/healthz")))
        XCTAssertFalse(LogNoise.isNoise(NetworkLog(key: "l", url: "https://api.uz/live/orders")))
        XCTAssertTrue(LogNoise.isNoise(NetworkLog(key: "i", url: "https://cdn.uz/img/logo.png")))
        XCTAssertFalse(LogNoise.isNoise(NetworkLog(key: "o", url: "https://api.uz/v1/orders/ready")))
        XCTAssertTrue(LogNoise.isNoise(NetworkLog(key: "ah", url: "https://api.uz/api/health")))
        XCTAssertFalse(LogNoise.isNoise(NetworkLog(key: "adj", url: "https://adjustments.example.uz/v1/x")))
        XCTAssertTrue(LogNoise.isNoise(NetworkLog(key: "adjh", url: "https://app.adjust.com/x")))
        XCTAssertTrue(LogNoise.isNoise(NetworkLog(key: "fb", url: "https://firebaseinstallations.googleapis.com/v1/x")))
    }

    func testHighlightHonorsWordBoundaries() {
        let spans = JSONFormat.highlight("{\"truex\": true, \"n\": -5, \"s\": \"a-b\"}")
        let boolNull = spans.filter { $0.kind == .boolNull }.map(\.text)
        XCTAssertEqual(boolNull, ["true"])
        let numbers = spans.filter { $0.kind == .number }.map(\.text)
        XCTAssertEqual(numbers, ["-5"])
        XCTAssertTrue(spans.contains(where: { $0.kind == .key && $0.text.contains("truex") }))
    }

    func testRawBodyKeepsServerFormatting() {
        let log = NetworkLog(key: "r", url: "https://a.uz/x", responseBody: "{\"a\":1,\"b\":[1,2]}")
        XCTAssertEqual(JSONFormat.body(for: log, tab: .response, pretty: false), "{\"a\":1,\"b\":[1,2]}")
        XCTAssertTrue(JSONFormat.body(for: log, tab: .response, pretty: true).contains("\n"))
    }

    func testFavoriteKeyHashIsStableAndPruned() {
        XCTAssertEqual(FavoriteKey.hash("abc"), FavoriteKey.hash("abc"))
        XCTAssertNotEqual(FavoriteKey.hash("abc"), FavoriteKey.hash("abd"))
        let live: Set<String> = ["k1", "k2"]
        var hashes = Set((0..<(FavoriteKey.maxStored + 40)).map { FavoriteKey.hash("stale\($0)") })
        hashes.insert(FavoriteKey.hash("k1"))
        let pruned = FavoriteKey.prune(hashes, live: live)
        XCTAssertTrue(pruned.contains(FavoriteKey.hash("k1")))
        XCTAssertLessThanOrEqual(pruned.count, FavoriteKey.maxStored)
    }

    func testSSEDecoderSurfacesServerErrorEvent() {
        var decoder = SSEDecoder()
        XCTAssertNil(decoder.feed(line: "event: error"))
        XCTAssertNil(decoder.feed(line: "data: pid map failed"))
        let event = decoder.feed(line: "")
        XCTAssertEqual(event?.event, "error")
        XCTAssertEqual(event?.data, "pid map failed")
    }

    func testLogBatcherTimerFlushesWithoutFurtherInput() async throws {
        let box = Box()
        let batcher = LogBatcher { logs in await box.append(logs) }
        await batcher.add(NetworkLog(key: "one"))
        let pendingBefore = await batcher.pendingCount
        XCTAssertEqual(pendingBefore, 1)
        try await Task.sleep(nanoseconds: LogBatcher.maxDelayNanos * 4)
        let delivered = await box.all
        XCTAssertEqual(delivered.flatMap { $0.map(\.key) }, ["one"])
        let pendingAfter = await batcher.pendingCount
        XCTAssertEqual(pendingAfter, 0)
    }

    func testLogBatcherFlushesAtMaxCount() async {
        let box = Box()
        let batcher = LogBatcher { logs in await box.append(logs) }
        for i in 0..<LogBatcher.maxCount { await batcher.add(NetworkLog(key: "k\(i)")) }
        let delivered = await box.all
        XCTAssertEqual(delivered.count, 1)
        XCTAssertEqual(delivered.first?.count, LogBatcher.maxCount)
    }

    private actor Box {
        var all: [[NetworkLog]] = []
        func append(_ logs: [NetworkLog]) { all.append(logs) }
    }
}
