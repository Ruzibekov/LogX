import XCTest
import Darwin
@testable import LogX
@testable import LogXCore

@MainActor
final class MemoryBaselineTests: XCTestCase {
    private func realisticBody(_ index: Int, rows: Int) -> String {
        var out = "{\"ok\":true,\"page\":\(index),\"items\":["
        for row in 0..<rows {
            out += "{\"id\":\(index * 1000 + row),\"name\":\"Foydalanuvchi \(row)\",\"pinfl\":\"3120199\(row % 10)12345\",\"address\":\"Toshkent shahar, Yunusobod tumani, \(row)-uy\",\"amount\":\(row * 1250),\"active\":\(row % 2 == 0),\"updatedAt\":\"2026-09-2\(row % 9)T10:1\(row % 6):00Z\"}"
            if row < rows - 1 { out += "," }
        }
        return out + "]}"
    }

    private func randomBody(_ bytes: Int) -> String {
        var out = ""
        out.reserveCapacity(bytes)
        var seed: UInt64 = 0x2545_F491_4F6C_DD1D
        let alphabet = Array("0123456789abcdef")
        while out.utf8.count < bytes {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            out.append(alphabet[Int((seed >> 33) % 16)])
        }
        return out
    }

    private func makeLog(_ index: Int, rows: Int, incompressible: Int = 0) -> NetworkLog {
        NetworkLog(
            key: "req-\(index)-abcdef0123456789",
            method: index % 4 == 0 ? "POST" : "GET",
            url: "https://api.online-mahalla.uz/v2/assistant/household/list?page=\(index)&size=20&mahallaId=1043",
            responseCode: index % 17 == 0 ? 500 : 200,
            durationMs: 80 + index % 400,
            packageName: "uz.online.mahalla",
            serial: "R58M1234ABC",
            deviceModel: "SM-A525F",
            appVersion: "1.2.7",
            ts: Double(1_700_000_000 + index),
            requestHeaders: [
                "Authorization": "Bearer " + String(repeating: "eyJhbGciOiJIUzI1NiJ9.", count: 12),
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": "okhttp/4.12.0",
                "device-id": "a1b2c3d4e5f6",
                "Accept-Language": "uz-UZ",
                "X-App-Version": "1.2.7",
            ],
            responseHeaders: [
                "Content-Type": "application/json; charset=utf-8",
                "Date": "Tue, 22 Sep 2026 10:15:00 GMT",
                "Server": "nginx/1.24.0",
                "X-Trace-Id": "00-\(index)-abcdef0123456789-01",
                "Cache-Control": "no-store",
                "Content-Encoding": "gzip",
            ],
            requestBody: index % 4 == 0 ? "{\"mahallaId\":1043,\"page\":\(index),\"filters\":{\"active\":true,\"tumanId\":12}}" : nil,
            responseBody: incompressible > 0 ? randomBody(incompressible) : realisticBody(index, rows: rows),
            isFull: true
        )
    }

    private func feed(_ store: LogStore, count: Int, rows: Int, incompressible: Int = 0) {
        for start in stride(from: 0, to: count, by: 25) {
            store.ingestBatch((start..<min(start + 25, count)).map { makeLog($0, rows: rows, incompressible: incompressible) })
        }
    }

    func testRealisticSessionFootprint() {
        let before = Footprint.megabytes()
        let store = LogStore()
        feed(store, count: 2500, rows: 40)
        let used = Footprint.megabytes() - before
        print("LOGX-MEM realistic2500x7KB=\(String(format: "%.1f", used)) MB struct=\(MemoryLayout<NetworkLog>.size)")
        XCTAssertEqual(store.liveByKey.count, 2500)
        XCTAssertLessThan(used, 20, "2500 log \(used) MB yedi")
    }

    func testIncompressibleBodiesStayInsideBudget() {
        let before = Footprint.megabytes()
        let store = LogStore()
        feed(store, count: 300, rows: 0, incompressible: 64 * 1024)
        let used = Footprint.megabytes() - before
        print("LOGX-MEM incompressible300x64KB=\(String(format: "%.1f", used)) MB estimate=\(store.bodyBytesEstimate / 1024) KB")
        XCTAssertEqual(store.allLogs.count, 300)
        XCTAssertLessThanOrEqual(store.bodyBytesEstimate, BodyBudget.totalBodyBytes)
        XCTAssertLessThan(used, 18, "byudjet \(used) MB yedi")
    }

    func testHeavySessionFootprint() {
        let before = Footprint.megabytes()
        let store = LogStore()
        feed(store, count: 600, rows: 300)
        let used = Footprint.megabytes() - before
        print("LOGX-MEM heavy600x50KB=\(String(format: "%.1f", used)) MB estimate=\(store.bodyBytesEstimate / 1024) KB")
        XCTAssertEqual(store.liveByKey.count, 600)
        XCTAssertLessThan(used, 14, "og'ir sessiya \(used) MB yedi")
    }

    func testBodiesAreStoredCompressed() {
        var raw = 0
        var packed = 0
        for index in 0..<200 {
            let log = makeLog(index, rows: 40)
            raw += (log.responseBody?.utf8.count ?? 0) + (log.requestBody?.utf8.count ?? 0)
            packed += BodyBudget.bytes(log)
        }
        print("LOGX-MEM ratio raw=\(raw / 1024) KB packed=\(packed / 1024) KB")
        XCTAssertGreaterThan(raw, 0)
        XCTAssertLessThan(packed, raw / 5, "siqish nisbati kutilgandan past: \(raw) → \(packed)")
    }

    func testMetadataFootprint() {
        let before = Footprint.megabytes()
        var logs: [NetworkLog] = []
        logs.reserveCapacity(2500)
        for index in 0..<2500 {
            var log = makeLog(index, rows: 1)
            log.requestBody = nil
            log.responseBody = nil
            logs.append(log)
        }
        let used = Footprint.megabytes() - before
        print("LOGX-MEM metadata2500=\(String(format: "%.1f", used)) MB pool=\(StringPool.shared.count)")
        XCTAssertEqual(logs.count, 2500)
        XCTAssertLessThan(used, 5.5, "metama \(used) MB yedi")
    }
}
