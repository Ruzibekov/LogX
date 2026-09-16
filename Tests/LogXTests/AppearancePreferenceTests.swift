import XCTest
@testable import LogXCore

final class AppearancePreferenceTests: XCTestCase {
    private func freshDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        UserDefaults(suiteName: name)!
    }

    func testDefaultsToDarkWhenNothingStored() {
        XCTAssertEqual(AppearancePreference.load(freshDefaults()), .dark)
    }

    func testRoundTripsEveryCase() {
        for option in AppearancePreference.allCases {
            let defaults = freshDefaults()
            option.save(defaults)
            XCTAssertEqual(AppearancePreference.load(defaults), option)
        }
    }

    func testUnknownValueFallsBackToDark() {
        let defaults = freshDefaults()
        defaults.set("neon", forKey: AppearancePreference.storageKey)
        XCTAssertEqual(AppearancePreference.load(defaults), .dark)
    }

    func testTitlesAreDistinctAndNonEmpty() {
        let titles = AppearancePreference.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
        XCTAssertFalse(titles.contains(where: \.isEmpty))
    }
}
