import XCTest
@testable import LogXCore

final class ReconnectBackoffTests: XCTestCase {
    func testStableConnectionResetsToInitial() {
        XCTAssertEqual(ReconnectBackoff.afterDrop(current: 3.2, connectedFor: ReconnectBackoff.stableAfter), ReconnectBackoff.initial)
        XCTAssertEqual(ReconnectBackoff.afterDrop(current: 3.2, connectedFor: 60), ReconnectBackoff.initial)
    }

    func testQuickDropsGrowUntilCap() {
        var delay: TimeInterval = 0
        var seen: [TimeInterval] = []
        for _ in 0..<8 {
            delay = ReconnectBackoff.afterDrop(current: delay, connectedFor: 0.1)
            seen.append(delay)
        }
        XCTAssertEqual(seen.first, ReconnectBackoff.initial)
        XCTAssertEqual(seen, seen.sorted(), "\(seen)")
        XCTAssertLessThanOrEqual(seen.last ?? 0, ReconnectBackoff.maxDelay)
        XCTAssertGreaterThan(seen.last ?? 0, ReconnectBackoff.initial)
    }

    func testFirstDropStartsAtInitial() {
        XCTAssertEqual(ReconnectBackoff.afterDrop(current: 0, connectedFor: 0), ReconnectBackoff.initial)
    }

    func testStreamPulseReportsIdle() async {
        let pulse = StreamPulse()
        await pulse.beat()
        let fresh = await pulse.idle()
        XCTAssertLessThan(fresh, 1)
    }
}
