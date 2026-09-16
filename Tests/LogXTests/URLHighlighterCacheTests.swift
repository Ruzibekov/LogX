import XCTest
@testable import LogXCore

final class URLHighlighterCacheTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLHighlighter.clearCache()
    }

    func testRepeatCallsGiveTheSameResult() {
        let url = "https://api.example.uz/v1/users?page=2"
        let first = URLHighlighter.attributed(url, baseFontSize: 13, selected: false)
        let second = URLHighlighter.attributed(url, baseFontSize: 13, selected: false)
        XCTAssertEqual(String(first.characters), String(second.characters))
        XCTAssertEqual(AttributedCache.count, 1)
    }

    func testSizeAndSelectionAreSeparateEntries() {
        let url = "https://api.example.uz/v1/users"
        _ = URLHighlighter.attributed(url, baseFontSize: 13, selected: false)
        _ = URLHighlighter.attributed(url, baseFontSize: 13, selected: true)
        _ = URLHighlighter.attributed(url, baseFontSize: 11, selected: false)
        XCTAssertEqual(AttributedCache.count, 3)
    }

    func testCacheNeverGrowsPastCapacity() {
        for i in 0..<(AttributedCache.capacity + 40) {
            _ = URLHighlighter.attributed("https://h/\(i)", baseFontSize: 13, selected: false)
        }
        XCTAssertLessThanOrEqual(AttributedCache.count, AttributedCache.capacity)
    }

    func testCachedTextMatchesFreshBuild() {
        let url = "https://h:8080/a/b?c=d#frag"
        let cached = URLHighlighter.attributed(url, baseFontSize: 13, selected: true)
        let fresh = URLHighlighter.build(url, baseFontSize: 13, selected: true)
        XCTAssertEqual(String(cached.characters), String(fresh.characters))
    }
}
