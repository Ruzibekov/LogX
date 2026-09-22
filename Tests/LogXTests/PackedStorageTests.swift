import XCTest
@testable import LogXCore

final class PackedTextTests: XCTestCase {
    func testEmptyAndNilStayEmpty() {
        XCTAssertNil(PackedText(nil).text)
        XCTAssertNil(PackedText("").text)
        XCTAssertTrue(PackedText(nil).isEmpty)
        XCTAssertEqual(PackedText(nil).storedBytes, 0)
    }

    func testShortTextIsKeptAsIs() {
        let packed = PackedText("{\"a\":1}")
        XCTAssertEqual(packed.text, "{\"a\":1}")
        XCTAssertEqual(packed.byteCount, 7)
        XCTAssertEqual(packed.storedBytes, 0, "qatorga sig'adigan matn heap'ga chiqmaydi")
    }

    func testLargeJSONRoundTripsAndShrinks() {
        let body = "[" + (0..<2000).map { "{\"id\":\($0),\"name\":\"Foydalanuvchi \($0)\"}" }.joined(separator: ",") + "]"
        let packed = PackedText(body)
        XCTAssertEqual(packed.text, body)
        XCTAssertEqual(packed.byteCount, body.utf8.count)
        XCTAssertLessThan(packed.storedBytes, body.utf8.count / 4, "siqilmagan: \(packed.storedBytes)")
    }

    func testMultibyteTextRoundTrips() {
        let body = String(repeating: "Тошкент шаҳар, Юнусобод тумани — ўзбек матни. ", count: 200)
        let packed = PackedText(body)
        XCTAssertEqual(packed.text, body)
        XCTAssertFalse(packed.text?.contains("\u{FFFD}") == true)
    }

    func testIncompressibleTextIsStoredRaw() {
        var body = ""
        var seed: UInt64 = 88_172_645_463_325_252
        while body.utf8.count < 4096 {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            body.append(Character(UnicodeScalar(UInt8(48 + seed % 74))))
        }
        let packed = PackedText(body)
        XCTAssertEqual(packed.text, body)
        XCTAssertLessThanOrEqual(packed.storedBytes, body.utf8.count)
    }

    func testContainsIsCaseInsensitiveOnPackedText() {
        let body = "[" + (0..<500).map { "{\"pinfl\":\"3120199\($0)\",\"NAME\":\"Aziza\"}" }.joined(separator: ",") + "]"
        let packed = PackedText(body)
        XCTAssertTrue(packed.contains("aziza"))
        XCTAssertTrue(packed.contains("PINFL"))
        XCTAssertFalse(packed.contains("Toshkent"))
        XCTAssertFalse(packed.contains(""))
    }
}

final class PackedHeadersTests: XCTestCase {
    private let headers = [
        "Authorization": "Bearer " + String(repeating: "eyJhbGciOiJIUzI1NiJ9.", count: 10),
        "Content-Type": "application/json",
        "X-Trace-Id": "00-abcdef0123456789-01",
    ]

    func testRoundTripKeepsEveryPair() {
        let packed = PackedHeaders(headers)
        XCTAssertEqual(packed.map, headers)
        XCTAssertFalse(packed.isEmpty)
    }

    func testEmptyMapStaysEmpty() {
        XCTAssertTrue(PackedHeaders([:]).isEmpty)
        XCTAssertEqual(PackedHeaders([:]).map, [:])
        XCTAssertEqual(PackedHeaders().storedBytes, 0)
    }

    func testEmptyValueSurvives() {
        let packed = PackedHeaders(["X-Empty": "", "X-Set": "1"])
        XCTAssertEqual(packed.map, ["X-Empty": "", "X-Set": "1"])
    }

    func testHeadersShrinkInRam() {
        let packed = PackedHeaders(headers)
        let raw = headers.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count }
        XCTAssertLessThan(packed.storedBytes, raw / 2, "sarlavhalar siqilmadi: \(packed.storedBytes)")
    }

    func testSearchFindsKeyAndValue() {
        let packed = PackedHeaders(headers)
        XCTAssertTrue(packed.contains("authorization"))
        XCTAssertTrue(packed.contains("application/json"))
        XCTAssertFalse(packed.contains("Cookie"))
    }
}

final class StringPoolTests: XCTestCase {
    func testEqualLongStringsShareOneInstance() {
        let pool = StringPool()
        let host = "api.online-mahalla.uz"
        let first = pool.intern(host)
        let second = pool.intern(String(host.reversed().reversed()))
        XCTAssertEqual(first, second)
        XCTAssertEqual(pool.count, 1)
    }

    func testShortStringsNeverEnterThePool() {
        let pool = StringPool()
        _ = pool.intern("GET")
        _ = pool.intern("1.2.7")
        XCTAssertEqual(pool.count, 0)
    }

    func testPoolStopsGrowingAtTheLimit() {
        let pool = StringPool()
        for index in 0..<(StringPool.limit + 50) {
            _ = pool.intern("host-\(index)-aaaaaaaaaaaaaaaaaaaa")
        }
        XCTAssertEqual(pool.count, StringPool.limit)
        XCTAssertEqual(pool.intern("host-1-aaaaaaaaaaaaaaaaaaaa"), "host-1-aaaaaaaaaaaaaaaaaaaa")
    }

    func testNilPassesThrough() {
        XCTAssertNil(StringPool().intern(nil))
    }
}

final class NetworkLogDerivedTests: XCTestCase {
    private func log(url: String, appId: String? = nil, packageName: String? = nil, method: String = "get") -> NetworkLog {
        NetworkLog(key: "k", method: method, url: url, packageName: packageName, appId: appId, serial: "S1")
    }

    func testMethodIsNormalisedOnce() {
        XCTAssertEqual(log(url: "https://h/x", method: "post").method, "POST")
    }

    func testNoiseFlagFollowsTheURL() {
        var item = log(url: "https://api.online-mahalla.uz/v2/list")
        XCTAssertFalse(item.isNoise)
        XCTAssertFalse(LogNoise.isNoise(item))
        item.url = "https://firebase.googleapis.com/v1/events"
        XCTAssertTrue(item.isNoise)
        XCTAssertTrue(LogNoise.isNoise(item))
        item.url = "https://api.online-mahalla.uz/v2/list"
        XCTAssertFalse(item.isNoise)
    }

    func testResolvedAppIdFollowsPackageAndAppId() {
        var item = log(url: "https://api.example.uz/v1/x")
        XCTAssertEqual(item.resolvedAppId, AppProfile.unknownId)
        item.packageName = "uz.online.mahalla"
        XCTAssertEqual(item.resolvedAppId, "uz.online.mahalla")
        item.appId = "ijara"
        XCTAssertEqual(item.resolvedAppId, "ijara")
    }

    func testResolvedAppIdFollowsTheHost() {
        var item = log(url: "https://api.example.uz/v1/x")
        XCTAssertEqual(item.resolvedAppId, AppProfile.unknownId)
        item.url = "https://cdn1-mobile.online-mahalla.uz/img"
        XCTAssertEqual(item.resolvedAppId, "mahalla")
    }

    func testBodiesAndHeadersSurviveTheStore() {
        let body = "[" + (0..<500).map { "{\"id\":\($0)}" }.joined(separator: ",") + "]"
        var item = log(url: "https://h/x")
        item.responseBody = body
        item.requestHeaders = ["Authorization": "Bearer abc", "Accept": "application/json"]
        XCTAssertEqual(item.responseBody, body)
        XCTAssertEqual(item.requestHeaders["Authorization"], "Bearer abc")
        XCTAssertLessThan(item.responseBodyPacked.storedBytes, body.utf8.count / 3)
        item.responseBody = nil
        XCTAssertNil(item.responseBody)
        XCTAssertEqual(item.responseBodyPacked.storedBytes, 0)
    }
}
