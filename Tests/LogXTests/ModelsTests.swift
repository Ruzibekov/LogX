import XCTest
@testable import LogXCore

final class ModelsTests: XCTestCase {
    func testDecodeDevices() throws {
        let json = """
        {"ok":true,"devices":[{"serial":"A1","model":"V2202","preferred":true}]}
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(DevicesPayload.self, from: json)
        XCTAssertEqual(payload.devices.count, 1)
        XCTAssertEqual(payload.devices[0].title.contains("V2202"), true)
    }

    func testDecodeEmptyDevices() throws {
        let json = #"{"ok":false,"error":"adb failed"}"#.data(using: .utf8)!
        let payload = try JSONDecoder().decode(DevicesPayload.self, from: json)
        XCTAssertTrue(payload.devices.isEmpty)
        XCTAssertEqual(payload.error, "adb failed")
    }

    func testDecodeLogSlimAndFull() throws {
        let json = """
        {"key":"k1","value":{
          "method":"post",
          "url":"https://api.example/x",
          "responseCode":400,
          "durationMs":2100,
          "packageName":"uz.realsoft.onlineijara",
          "device":"vivo V2202",
          "ts":12,
          "_slim":true
        }}
        """.data(using: .utf8)!
        struct Wrapper: Decodable { let key: String; let value: LogValue }
        let wrapped = try JSONDecoder().decode(Wrapper.self, from: json)
        let log = wrapped.value.asLog(key: wrapped.key)
        XCTAssertEqual(log.method, "POST")
        XCTAssertEqual(log.responseCode, 400)
        XCTAssertEqual(log.statusClass, .err4xx)
        XCTAssertEqual(log.resolvedAppId, "ijara")
        XCTAssertEqual(log.durationMs, 2100)
        XCTAssertFalse(log.isFull)
    }

    func testDeviceLabelAndHost() {
        let log = NetworkLog(key: "k", device: "Xiaomi 2209116AG", requestHeaders: ["device-id": "abc-1"])
        XCTAssertEqual(log.fieldDeviceLabel, "Xiaomi 2209116AG")
        XCTAssertEqual(NetworkLog(key: "h", url: "https://api.online-mahalla.uz/v1/x").hostLabel, "api.online-mahalla.uz")
        XCTAssertEqual(NetworkLog(key: "e").fieldDeviceLabel, "—")
    }

    func testURLPartsAndPathLabelFollowUrlChanges() {
        let parts = URLParts.parse("https://api.example.uz/v1/items?page=2&q=a%20b")
        XCTAssertEqual(parts.host, "api.example.uz")
        XCTAssertEqual(parts.path, "/v1/items")
        XCTAssertEqual(parts.query, "page=2&q=a%20b")
        let bare = URLParts.parse("/only/path")
        XCTAssertEqual(bare.host, "")
        XCTAssertEqual(bare.path, "/only/path")
        XCTAssertEqual(bare.query, "")
        var log = NetworkLog(key: "u", url: "https://a.uz/x?y=1")
        XCTAssertEqual(log.pathLabel, "/x?y=1")
        log.url = "https://b.uz/z"
        XCTAssertEqual(log.hostLabel, "b.uz")
        XCTAssertEqual(log.pathOnly, "/z")
        XCTAssertEqual(log.pathLabel, "/z")
    }

    func testByteSizeLabelsAndInformationalStatus() {
        XCTAssertEqual(ByteSize.label(0), "0 B")
        XCTAssertEqual(ByteSize.label(512), "512 B")
        XCTAssertTrue(ByteSize.label(2048).hasSuffix("KB"))
        XCTAssertTrue(ByteSize.label(3 * 1024 * 1024).hasSuffix("MB"))
        XCTAssertEqual(NetworkLog(key: "i", responseCode: 101).statusClass, .ok2xx)
    }

    func testStatusNetWhenNoCode() {
        XCTAssertEqual(NetworkLog(key: "n").statusClass, .net)
        XCTAssertEqual(NetworkLog(key: "s", responseCode: 502).statusClass, .err5xx)
    }

    func testMonitorClientHasNoNetworkLogRoutes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let src = try String(
            contentsOf: root.appendingPathComponent("Sources/LogXCore/MonitorClient.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(src.contains("/api/network-logs"), src)
        XCTAssertFalse(src.contains("/api/demo-network-logs"), src)
        XCTAssertFalse(src.contains("func logDetail"), src)
        XCTAssertFalse(src.contains("func detailPaths"), src)
    }
}
