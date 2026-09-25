import XCTest
@testable import LogXCore

final class SignalTraceTests: XCTestCase {
    private func log(_ key: String, ms: Int?, code: Int? = 200) -> NetworkLog {
        NetworkLog(key: key, method: "GET", url: "https://h.uz/\(key)", api: "/\(key)", responseCode: code, durationMs: ms, ts: 1_789_000_000_000)
    }

    func testEmptyInputAndZeroLimitProduceNoPoints() {
        XCTAssertTrue(SignalTrace.points([]).isEmpty)
        XCTAssertTrue(SignalTrace.points([log("a", ms: 10)], limit: 0).isEmpty)
    }

    func testNewestLogIsRightmostAndOldestIsLeft() {
        let logs = [log("new", ms: 50), log("mid", ms: 60), log("old", ms: 70)]
        let points = SignalTrace.points(logs, limit: 5)
        XCTAssertEqual(points.map(\.key), ["old", "mid", "new"])
        XCTAssertEqual(points.last?.x ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(points[1].x, 0.75, accuracy: 1e-9)
        XCTAssertEqual(points[0].x, 0.5, accuracy: 1e-9)
    }

    func testFullWindowSpansWholeWidth() {
        let logs = (0..<4).map { log("k\($0)", ms: 100) }
        let points = SignalTrace.points(logs, limit: 4)
        XCTAssertEqual(points.first?.x ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(points.last?.x ?? -1, 1, accuracy: 1e-9)
    }

    func testWindowIsCappedByLimit() {
        let logs = (0..<100).map { log("k\($0)", ms: 100) }
        XCTAssertEqual(SignalTrace.points(logs, limit: 72).count, 72)
        XCTAssertEqual(SignalTrace.points(logs, limit: 72).last?.key, "k0")
    }

    func testUnmeasuredRequestSitsOnBaseline() {
        let points = SignalTrace.points([log("net", ms: nil, code: nil), log("ok", ms: 120)], limit: 10)
        let net = points.first { $0.key == "net" }
        XCTAssertEqual(net?.y ?? -1, SignalTrace.baselineY, accuracy: 1e-9)
        XCTAssertEqual(net?.level, .unmeasured)
        XCTAssertEqual(net?.statusClass, .net)
    }

    func testSlowSpikeExceedsTypicalBandAndClampsAtTop() {
        let typical = (0..<10).map { log("t\($0)", ms: 100) }
        let logs = [log("spike", ms: 4000)] + typical
        let points = SignalTrace.points(logs, limit: 20)
        let spike = points.first { $0.key == "spike" }!
        let normal = points.first { $0.key == "t0" }!
        XCTAssertEqual(spike.y, 1, accuracy: 1e-9)
        XCTAssertLessThan(normal.y, 0.5)
        XCTAssertGreaterThan(normal.y, SignalTrace.baselineY)
        XCTAssertEqual(spike.level, .verySlow)
        XCTAssertEqual(normal.level, .normal)
    }

    func testAmplitudeIsMonotonicAndBounded() {
        let ref = 250.0
        let values = [1.0, 50, 100, 200, 250, 900, 50_000].map { SignalTrace.amplitude($0, reference: ref) }
        XCTAssertEqual(values, values.sorted())
        XCTAssertTrue(values.allSatisfy { $0 >= SignalTrace.baselineY && $0 <= 1 })
        XCTAssertEqual(SignalTrace.amplitude(0, reference: ref), SignalTrace.baselineY)
        XCTAssertEqual(SignalTrace.amplitude(100, reference: 0), SignalTrace.baselineY)
    }

    func testReferenceHasFloorForTinyDurations() {
        XCTAssertEqual(SignalTrace.reference([]), SignalTrace.referenceFloorMs)
        XCTAssertEqual(SignalTrace.reference([2, 3, 4]), SignalTrace.referenceFloorMs)
        XCTAssertEqual(SignalTrace.reference([100, 100, 100, 100]), 250, accuracy: 1e-9)
    }

    func testLevelsFollowLogNoiseThresholds() {
        XCTAssertEqual(SignalTrace.level(nil), .unmeasured)
        XCTAssertEqual(SignalTrace.level(0), .unmeasured)
        XCTAssertEqual(SignalTrace.level(Double(LogNoise.slowThresholdMs - 1)), .normal)
        XCTAssertEqual(SignalTrace.level(Double(LogNoise.slowThresholdMs)), .slow)
        XCTAssertEqual(SignalTrace.level(Double(LogNoise.verySlowThresholdMs)), .verySlow)
    }

    func testNearestPicksClosestPoint() {
        let points = SignalTrace.points([log("c", ms: 10), log("b", ms: 10), log("a", ms: 10)], limit: 3)
        XCTAssertEqual(SignalTrace.nearest(points, toX: 0.1)?.key, "a")
        XCTAssertEqual(SignalTrace.nearest(points, toX: 0.55)?.key, "b")
        XCTAssertEqual(SignalTrace.nearest(points, toX: 2)?.key, "c")
        XCTAssertNil(SignalTrace.nearest([], toX: 0.5))
    }

    func testSingleSlotLimitPlacesPointAtRightEdge() {
        let points = SignalTrace.points([log("only", ms: 30)], limit: 1)
        XCTAssertEqual(points.map(\.x), [1])
        XCTAssertEqual(SignalTrace.step(limit: 1), 0)
    }
}
