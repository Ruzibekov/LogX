import XCTest
@testable import LogXCore

final class LatencySummaryTests: XCTestCase {
    private func log(_ key: String, ms: Int?, code: Int?) -> NetworkLog {
        NetworkLog(key: key, method: "GET", url: "https://h/x", api: "/x", responseCode: code, durationMs: ms, ts: 1)
    }

    func testPercentileOnEmptyIsNil() {
        XCTAssertNil(LatencySummary.percentile([], 0.95))
    }

    func testPercentileSingleValue() {
        XCTAssertEqual(LatencySummary.percentile([42], 0.95), 42)
    }

    func testPercentileInterpolates() {
        let value = LatencySummary.percentile([10, 20, 30, 40], 0.5)
        XCTAssertEqual(value ?? 0, 25, accuracy: 0.0001)
    }

    func testPercentileClampsOutOfRangeProbability() {
        XCTAssertEqual(LatencySummary.percentile([10, 20, 30], 5) ?? 0, 30, accuracy: 0.0001)
        XCTAssertEqual(LatencySummary.percentile([10, 20, 30], -1) ?? 0, 10, accuracy: 0.0001)
    }

    func testBarsAreReversedSoNewestIsLast() {
        let logs = [log("c", ms: 30, code: 200), log("b", ms: 20, code: 200), log("a", ms: 10, code: 200)]
        XCTAssertEqual(LatencySummary.bars(logs).map(\.key), ["a", "b", "c"])
    }

    func testBarsRespectLimit() {
        let logs = (0..<200).map { log("k\($0)", ms: $0 + 1, code: 200) }
        XCTAssertEqual(LatencySummary.bars(logs, limit: 10).count, 10)
        XCTAssertTrue(LatencySummary.bars(logs, limit: 0).isEmpty)
    }

    func testSlowestBarIsFullHeightAndAllAreClamped() {
        let logs = [log("slow", ms: 2000, code: 200), log("fast", ms: 5, code: 200)]
        let bars = LatencySummary.bars(logs)
        XCTAssertEqual(bars.first(where: { $0.key == "slow" })?.ratio ?? 0, 1, accuracy: 0.0001)
        for bar in bars {
            XCTAssertGreaterThanOrEqual(bar.ratio, 0.06)
            XCTAssertLessThanOrEqual(bar.ratio, 1)
        }
    }

    func testMissingDurationStillDrawsMinimumBar() {
        let bars = LatencySummary.bars([log("net", ms: nil, code: nil)])
        XCTAssertEqual(bars.count, 1)
        XCTAssertEqual(bars[0].ratio, 0.06, accuracy: 0.0001)
        XCTAssertEqual(bars[0].statusClass, .net)
    }

    func testP95LabelFormatsMillisecondsAndSeconds() {
        let fast = (0..<20).map { log("f\($0)", ms: 100, code: 200) }
        XCTAssertEqual(LatencySummary.p95Label(fast), "p95 100 ms")
        let slow = (0..<20).map { log("s\($0)", ms: 2400, code: 200) }
        XCTAssertEqual(LatencySummary.p95Label(slow), "p95 2.40 s")
        XCTAssertNil(LatencySummary.p95Label([log("n", ms: nil, code: nil)]))
    }
}
