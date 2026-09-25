import XCTest
@testable import LogXCore

final class AdbConflictTests: XCTestCase {
    func testDecodesConflictFromDevicesPayload() throws {
        let json = """
        {"ok":true,"devices":[],"adbConflict":{"port":5038,"pid":30963,"serials":["97750348124377"],"fix":"adb -P 5038 kill-server && adb kill-server && adb devices"}}
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(DevicesPayload.self, from: json)
        XCTAssertEqual(payload.adbConflict, AdbConflict(
            port: 5038,
            pid: 30963,
            serials: ["97750348124377"],
            fix: "adb -P 5038 kill-server && adb kill-server && adb devices"
        ))
    }

    func testNullOrMissingConflictDecodesAsNil() throws {
        let explicitNull = #"{"ok":true,"devices":[],"adbConflict":null}"#.data(using: .utf8)!
        let missing = #"{"ok":true,"devices":[]}"#.data(using: .utf8)!
        XCTAssertNil(try JSONDecoder().decode(DevicesPayload.self, from: explicitNull).adbConflict)
        XCTAssertNil(try JSONDecoder().decode(DevicesPayload.self, from: missing).adbConflict)
    }

    func testMalformedConflictDoesNotBreakDeviceList() throws {
        let json = #"{"ok":true,"devices":[{"serial":"A1","model":"V2202","preferred":false}],"adbConflict":{"port":"x"}}"#.data(using: .utf8)!
        let payload = try JSONDecoder().decode(DevicesPayload.self, from: json)
        XCTAssertEqual(payload.devices.map(\.serial), ["A1"])
        XCTAssertNil(payload.adbConflict)
    }

    func testMissingFixFallsBackToKillCommand() throws {
        let json = #"{"devices":[],"adbConflict":{"port":6000,"serials":["S1"]}}"#.data(using: .utf8)!
        let conflict = try XCTUnwrap(try JSONDecoder().decode(DevicesPayload.self, from: json).adbConflict)
        XCTAssertNil(conflict.pid)
        XCTAssertEqual(conflict.fix, "adb -P 6000 kill-server && adb kill-server && adb devices")
    }

    func testSubtitleNamesDevicePortAndPid() {
        let one = AdbConflict(port: 5038, pid: 30963, serials: ["97750348124377"], fix: "")
        XCTAssertEqual(
            one.subtitle,
            "97750348124377 ulangan, lekin uni 5038-portdagi boshqa adb server (pid 30963) band qilgan. LogX 5037-portni ko'radi."
        )
        let many = AdbConflict(port: 6000, pid: nil, serials: ["A", "B"], fix: "")
        XCTAssertEqual(
            many.subtitle,
            "2 ta qurilma ulangan, lekin ularni 6000-portdagi boshqa adb server band qilgan. LogX 5037-portni ko'radi."
        )
    }
}
