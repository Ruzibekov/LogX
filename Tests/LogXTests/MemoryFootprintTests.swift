import XCTest
import Darwin
@testable import LogX
@testable import LogXCore

/// Jarayonning haqiqiy xotira izi (phys_footprint).
enum Footprint {
    static func megabytes() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576
    }
}

@MainActor
final class MemoryFootprintTests: XCTestCase {
    private func makeLog(_ index: Int, bodyKB: Int) -> NetworkLog {
        let body = String(repeating: "{\"field\":\"value\",\"n\":\(index)},", count: bodyKB * 1024 / 24)
        return NetworkLog(
            key: "k\(index)",
            method: "POST",
            url: "https://api.example.uz/v1/resource/\(index)?page=\(index)",
            responseCode: 200,
            durationMs: 120,
            serial: "S1",
            ts: Double(1_700_000_000 + index),
            requestHeaders: ["Authorization": String(repeating: "t", count: 800)],
            responseHeaders: ["X-Trace": String(repeating: "x", count: 800)],
            requestBody: body,
            responseBody: body
        )
    }

    private func feed(_ store: LogStore, count: Int, bodyKB: Int) {
        for start in stride(from: 0, to: count, by: 20) {
            store.ingestBatch((start..<min(start + 20, count)).map { makeLog($0, bodyKB: bodyKB) })
        }
    }

    /// Jonli oqim byudjetda qoladi: tanalar 32 MB dan oshmaydi.
    func testLiveIngestStaysInsideBodyBudget() {
        let store = LogStore()
        feed(store, count: 1500, bodyKB: 200)
        XCTAssertLessThanOrEqual(store.bodyBytesEstimate, BodyBudget.totalBodyBytes)
        XCTAssertEqual(store.bodyBytesEstimate, BodyBudget.totalBytes(store.liveByKey.values))
    }

    /// Pauza buferi ham byudjetli — aks holda uzoq pauzada gigabaytga chiqardi.
    func testPausedBufferStaysInsideBudget() {
        let store = LogStore()
        store.isPaused = true
        let before = Footprint.megabytes()
        feed(store, count: 1500, bodyKB: 200)
        let delta = Footprint.megabytes() - before
        XCTAssertEqual(store.pendingWhilePausedCount, 1500)
        XCTAssertLessThanOrEqual(BodyBudget.totalBytes(store.pendingWhilePaused), BodyBudget.secondaryBodyBytes)
        XCTAssertLessThan(delta, 120, "pauza buferi \(delta) MB yedi")
    }

    /// Davom etilganda bufer to'liq kiradi va hisob jonli byudjetga o'tadi.
    func testResumeMovesBufferIntoBudget() {
        let store = LogStore()
        store.isPaused = true
        feed(store, count: 300, bodyKB: 200)
        store.togglePause()
        XCTAssertEqual(store.pendingWhilePausedCount, 0)
        XCTAssertEqual(store.allLogs.count, 300)
        XCTAssertLessThanOrEqual(store.bodyBytesEstimate, BodyBudget.totalBodyBytes)
    }

    /// Tozalash nusxasi metama bilan qoladi, tanalari byudjetgacha qisqaradi.
    func testClearSnapshotDropsBodiesOverBudget() {
        let store = LogStore()
        feed(store, count: 1000, bodyKB: 200)
        store.clearLogs()
        XCTAssertTrue(store.canUndoClear)
        XCTAssertLessThanOrEqual(BodyBudget.totalBytes(store.clearedSnapshot.values), BodyBudget.secondaryBodyBytes)
        store.undoClear()
        XCTAssertEqual(store.allLogs.count, 1000)
        XCTAssertEqual(store.bodyBytesEstimate, BodyBudget.totalBytes(store.liveByKey.values))
    }

    /// Qayta yuborish javobi ham hisobga tushadi va chegaralanadi.
    func testReplayInsertIsClampedAndCounted() {
        let store = LogStore()
        var replayed = makeLog(9999, bodyKB: 4096)
        replayed.key = "replay-1"
        store.insertReplay(replayed)
        let stored = store.liveByKey["replay-1"]
        XCTAssertNotNil(stored)
        XCTAssertLessThanOrEqual(stored?.responseBody?.utf8.count ?? 0, BodyBudget.maxBodyBytes + BodyBudget.truncatedNotice.utf8.count)
        XCTAssertEqual(store.bodyBytesEstimate, BodyBudget.totalBytes(store.liveByKey.values))
    }
}

@MainActor
final class RenderFootprintTests: XCTestCase {
    private func bigLog() -> NetworkLog {
        let body = String(repeating: "{\"field\":\"value\",\"n\":12345},", count: 512 * 1024 / 28)
        return NetworkLog(key: "big", method: "POST", url: "https://api.example.uz/v1/big", responseCode: 200, responseBody: body)
    }


    func testOversizedTreeIsRejectedWithoutBurningMemory() {
        let payload = "[" + (0..<20_000).map { "{\"id\":\($0),\"name\":\"row \($0)\"}" }.joined(separator: ",") + "]"
        let before = Footprint.megabytes()
        let tree = JSONTree(text: payload, identity: "big")
        let delta = Footprint.megabytes() - before
        XCTAssertNil(tree)
        XCTAssertLessThan(delta, 20, "chegaradan katta daraxt \(delta) MB yedi")
    }

    func testTreeStillBuildsUnderNodeLimit() {
        let payload = "[" + (0..<500).map { "{\"id\":\($0),\"name\":\"row \($0)\"}" }.joined(separator: ",") + "]"
        let tree = JSONTree(text: payload, identity: "small")
        XCTAssertNotNil(tree)
        XCTAssertGreaterThan(tree?.count ?? 0, 1000)
    }

    /// Bitta 512 KB tanani ranglash matn hajmidan 40× ko'p xotira yemaydi.
    func testRenderedBodyFootprint() {
        let log = bigLog()
        let key = RenderedBody.Key(logKey: log.key, tab: .response, redact: false, pretty: true, query: "", index: 0, tree: false)
        let before = Footprint.megabytes()
        let rendered = RenderedBody.make(log: log, key: key)
        let delta = Footprint.megabytes() - before
        XCTAssertGreaterThan(rendered.attributed.length, 0)
        XCTAssertLessThan(delta, 20, "512 KB tana \(delta) MB yedi")
    }
}
