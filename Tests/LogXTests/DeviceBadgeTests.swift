import XCTest
@testable import LogXCore

final class DeviceBadgeTests: XCTestCase {
    func testTwoWordsGiveTwoInitials() {
        XCTAssertEqual(DeviceBadge.initials("Pixel 8 Pro"), "P8")
        XCTAssertEqual(DeviceBadge.initials("Galaxy Tab"), "GT")
    }

    func testHyphenAndUnderscoreCountAsSeparators() {
        XCTAssertEqual(DeviceBadge.initials("vivo-v2202"), "VV")
        XCTAssertEqual(DeviceBadge.initials("moto_g"), "MG")
    }

    func testSingleWordTakesTheFirstTwoCharacters() {
        XCTAssertEqual(DeviceBadge.initials("V2202"), "V2")
        XCTAssertEqual(DeviceBadge.initials("iPhone"), "IP")
    }

    func testEmptyOrSymbolOnlyIsSafe() {
        XCTAssertEqual(DeviceBadge.initials("   "), "??")
        XCTAssertEqual(DeviceBadge.initials("**"), "??")
    }
}
