import XCTest
@testable import LogXCore

final class NetworkLogMetaTests: XCTestCase {
    func testRareMetaFieldsLiveOutOfLine() {
        XCTAssertLessThanOrEqual(MemoryLayout<NetworkLog>.size, 460, "NetworkLog inline size \(MemoryLayout<NetworkLog>.size)")
    }

    func testMetaFieldsRoundTripThroughInit() {
        let log = NetworkLog(
            key: "k", feature: "auth", source: "logcat", appVersion: "1.2", moduleId: "m1", moduleName: "Mod",
            environment: "prod", flavor: "uz", buildType: "debug", sessionId: "s1", userInfoPinfl: "123",
            assistantJshshir: "456", responseBodyMessage: "ok", photoCount: 3
        )
        XCTAssertEqual(log.feature, "auth")
        XCTAssertEqual(log.source, "logcat")
        XCTAssertEqual(log.appVersion, "1.2")
        XCTAssertEqual(log.moduleId, "m1")
        XCTAssertEqual(log.moduleName, "Mod")
        XCTAssertEqual(log.environment, "prod")
        XCTAssertEqual(log.flavor, "uz")
        XCTAssertEqual(log.buildType, "debug")
        XCTAssertEqual(log.sessionId, "s1")
        XCTAssertEqual(log.userInfoPinfl, "123")
        XCTAssertEqual(log.assistantJshshir, "456")
        XCTAssertEqual(log.responseBodyMessage, "ok")
        XCTAssertEqual(log.photoCount, 3)
    }

    func testMutatingCopyDoesNotLeakIntoOriginal() {
        let original = NetworkLog(key: "k", moduleName: "A")
        var copy = original
        copy.moduleName = "B"
        copy.photoCount = 7
        XCTAssertEqual(original.moduleName, "A")
        XCTAssertNil(original.photoCount)
        XCTAssertEqual(copy.moduleName, "B")
        XCTAssertNotEqual(original, copy)
    }

    func testEqualityComparesMetaByValue() {
        let a = NetworkLog(key: "k", environment: "prod", photoCount: 2)
        let b = NetworkLog(key: "k", environment: "prod", photoCount: 2)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, NetworkLog(key: "k", environment: "dev", photoCount: 2))
        XCTAssertEqual(NetworkLog(key: "k"), NetworkLog(key: "k"))
    }
}
