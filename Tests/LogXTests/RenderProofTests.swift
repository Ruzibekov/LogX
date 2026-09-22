import XCTest
import SwiftUI
import AppKit
import LogXCore
@testable import LogX

/// Yangi sirtlar haqiqatan chiziladimi — jonli qurilma trafigisiz tekshirish uchun
/// ko'rinishlar offscreen render qilinadi va `.screenshots/` ga yoziladi.
@MainActor
final class RenderProofTests: XCTestCase {
    private func store(_ logs: [NetworkLog]) -> LogStore {
        let s = LogStore()
        s.hideNoise = false
        s.followLatest = false
        s.slowOnly = false
        s.errorsOnly = false
        s.favoritesOnly = false
        s.status = .all
        s.selectedMethod = "ALL"
        s.selectedAppId = "all"
        s.selectedSerial = nil
        s.query = ""
        for log in logs { s.liveByKey[log.key] = log }
        s.rebuildFromLive()
        s.selectedKey = logs.first?.key
        s.connection = .live
        s.isLoading = false
        return s
    }

    private func sample() -> [NetworkLog] {
        let specs: [(String, String, String, Int?, Int)] = [
            ("a", "GET", "https://api.online-mahalla.uz/v3/mahalla/list?page=1", 200, 84),
            ("b", "POST", "https://api.online-mahalla.uz/v3/auth/login", 401, 612),
            ("c", "GET", "https://api.online-mahalla.uz/v3/profile/me", 200, 39),
            ("d", "PUT", "https://api.online-mahalla.uz/v3/appeal/1204", 500, 1840),
            ("e", "GET", "https://cdn.online-mahalla.uz/static/banner.png", nil, 220),
        ]
        return specs.enumerated().map { idx, spec in
            var log = NetworkLog(
                key: spec.0,
                method: spec.1,
                url: spec.2,
                api: spec.2,
                responseCode: spec.3,
                durationMs: spec.4,
                ts: 1_789_000_000_000 + Double(idx)
            )
            log.source = "logcat"
            log.responseBody = "{\"ok\":true,\"items\":[1,2,3]}"
            return log
        }
    }

    private func render<V: View>(_ view: V, size: CGSize, name: String) throws {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            return XCTFail("bitmap yaratilmadi: \(name)")
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            return XCTFail("png kodlanmadi: \(name)")
        }
        XCTAssertGreaterThan(png.count, 2000, name)
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try png.write(to: dir.appendingPathComponent("\(name).png"))
    }

    func testRequestRowRenders() throws {
        let logs = sample()
        let s = store(logs)
        let view = VStack(spacing: 0) {
            ForEach(logs) { log in
                RequestRow(log: log, selected: s.selectedKey == log.key, now: Date(), showAppColumn: s.hasMultipleLiveApps, showTimeColumn: true)
            }
        }
        .background(LogXTheme.bg)
        .environmentObject(s)
        try render(view, size: CGSize(width: 460, height: 280), name: "render-rows")
    }

    func testLatencyTimelineRenders() throws {
        let s = store(sample())
        try render(
            LatencyTimelineView().environmentObject(s),
            size: CGSize(width: 460, height: 80),
            name: "render-timeline"
        )
    }

    func testDetailHeaderRenders() throws {
        let logs = sample()
        let s = store(logs)
        try render(
            DetailHeader(log: logs[1], tab: .response).environmentObject(s),
            size: CGSize(width: 560, height: 220),
            name: "render-detail-header"
        )
    }

    func testEmptyStateRenders() throws {
        let s = store([])
        try render(
            RequestEmptyView().environmentObject(s).background(LogXTheme.bg),
            size: CGSize(width: 560, height: 420),
            name: "render-empty"
        )
    }

    func testFilterBarRenders() throws {
        let s = store(sample())
        try render(
            RequestFilterBar().environmentObject(s),
            size: CGSize(width: 560, height: 90),
            name: "render-filterbar"
        )
    }

    func testDeviceRailRenders() throws {
        let s = store(sample())
        try render(
            DeviceRail().environmentObject(s),
            size: CGSize(width: DeviceRail.width, height: 420),
            name: "render-rail"
        )
    }

    func testLiveBarRenders() throws {
        let s = store(sample())
        try render(
            RequestLiveBar(now: Date()).environmentObject(s),
            size: CGSize(width: 900, height: 34),
            name: "render-livebar"
        )
    }

    /// Oqim uzilganda bannerda xom ingliz `logcat` matni emas, bitta qatorli
    /// tushunarli xabar turishi kerak — ro'yxat ustida chizib tekshiriladi.
    func testStreamNoticeStripRenders() throws {
        let s = store(sample())
        let raw = #"{"message":"logcat: Unexpected EOF!\n\nThis means that either the device shut down, logd crashed, or this instance of logcat was unable to read log\nmessages as quickly as they were being produced."}"#
        s.handleStreamChunk(serial: "S", chunk: .serverError(raw))
        XCTAssertEqual(s.banner, "Log oqimi uzildi (bufer to'lib ketdi) — qayta ulanyapti")
        XCTAssertTrue(s.bannerIsStreamNotice)
        try render(
            RequestList().environmentObject(s),
            size: CGSize(width: 560, height: 420),
            name: "render-stream-notice"
        )
    }

    func testRequestListRenders() throws {
        let s = store(sample())
        try render(
            RequestList().environmentObject(s),
            size: CGSize(width: 460, height: 520),
            name: "render-list"
        )
    }

    func testRequestDetailRenders() throws {
        let logs = sample()
        let s = store(logs)
        s.selectedKey = logs[1].key
        try render(
            RequestDetail().environmentObject(s),
            size: CGSize(width: 760, height: 560),
            name: "render-detail"
        )
    }

    func testContentViewRenders() throws {
        let logs = sample()
        let s = store(logs)
        s.selectedKey = logs[1].key
        try render(
            ContentView().environmentObject(s),
            size: CGSize(width: 1440, height: 900),
            name: "render-contentview"
        )
    }

    func testDetailWithBodyKeepsHeaderVisible() throws {
        let logs = sample()
        let s = store(logs)
        s.selectedKey = logs[1].key
        let size = CGSize(width: 760, height: 560)
        let host = NSHostingView(rootView: RequestDetail().environmentObject(s).frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            return XCTFail("bitmap yaratilmadi")
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".screenshots")
            try? png.write(to: dir.appendingPathComponent("render-detail-body.png"))
        }
        var found = false
        for y in 0..<40 where !found {
            for x in stride(from: 0, to: Int(size.width), by: 4) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                if color.brightnessComponent > 0.3 { found = true; break }
            }
        }
        XCTAssertTrue(found, "inspektor sarlavhasi ko'rinmayapti — tana ko'rinishi uni surib yuborgan")
    }
}
