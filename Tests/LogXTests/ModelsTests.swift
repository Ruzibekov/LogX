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
        {"ok":true,"items":[{"key":"k1","value":{
          "method":"post",
          "url":"https://api.example/x",
          "responseCode":400,
          "durationMs":2100,
          "packageName":"uz.realsoft.onlineijara",
          "device":"vivo V2202",
          "ts":12,
          "_slim":true
        }}]}
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(LogsPayload.self, from: json)
        let log = payload.items[0].value.asLog(key: payload.items[0].key)
        XCTAssertEqual(log.method, "POST")
        XCTAssertEqual(log.responseCode, 400)
        XCTAssertEqual(log.statusClass, .err4xx)
        XCTAssertEqual(log.resolvedAppId, "ijara")
        XCTAssertEqual(log.durationMs, 2100)
        XCTAssertFalse(log.isFull)
    }

    func testFieldDeviceIdPrefersHeader() {
        let log = NetworkLog(
            key: "k",
            device: "Xiaomi 2209116AG",
            requestHeaders: ["device-id": "abc-1"]
        )
        XCTAssertEqual(log.fieldDeviceId, "abc-1")
        XCTAssertEqual(log.fieldDeviceLabel, "Xiaomi 2209116AG")
        XCTAssertEqual(NetworkLog(key: "h", url: "https://api.online-mahalla.uz/v1/x").hostLabel, "api.online-mahalla.uz")
        XCTAssertEqual(NetworkLog(key: "e").fieldDeviceLabel, "—")
    }

    func testStatusNetWhenNoCode() {
        XCTAssertEqual(NetworkLog(key: "n").statusClass, .net)
        XCTAssertEqual(NetworkLog(key: "s", responseCode: 502).statusClass, .err5xx)
    }

    func testEmptyLogsPayloadInit() {
        let empty = LogsPayload(ok: false, error: "502", items: [])
        XCTAssertTrue(empty.items.isEmpty)
        XCTAssertEqual(empty.error, "502")
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
