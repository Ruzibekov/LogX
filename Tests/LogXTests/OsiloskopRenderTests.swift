import XCTest
import SwiftUI
import AppKit
import LogXCore
@testable import LogX

@MainActor
final class OsiloskopRenderTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let loginBody = """
    {"data":{"access_token":"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI0NDEyIn0.x9Qf2kLm","expires_in":180000000,"refresh_expires_in":860000000,"refresh_token":"eyJhbGciOiJIUzI1NiJ9.eyJ0eXAiOiJSZWZyZXNoIn0.Qm7Zt0aP","token_type":"Bearer"},"status":"OK","timestamp":1790316546073}
    """

    private func sampleLogs(now: Date) -> [NetworkLog] {
        let specs: [(String, String, Int?, Int?, Double)] = [
            ("POST", "/api/v1/auth/login", 200, 184, 3),
            ("GET", "/api/v1/objects?page=1&size=20", 200, 96, 9),
            ("GET", "/api/v1/facturas?month=9&year=2026", 200, 312, 15),
            ("GET", "/api/v1/profile/me", 401, 41, 21),
            ("POST", "/api/v1/auth/refresh", 200, 128, 27),
            ("GET", "/api/v1/profile/me", 200, 77, 33),
            ("POST", "/api/v1/inspector/candidates", 500, 1840, 41),
            ("GET", "/api/v1/contracts?status=ACCEPTED", 200, 264, 48),
            ("GET", "/api/v1/contracts/SH-2024-0999", 404, 58, 55),
            ("GET", "/api/v1/regions/tree", 200, 912, 61),
            ("PUT", "/api/v1/objects/4412/location", 200, 143, 68),
            ("GET", "/api/v1/notifications/unread", 200, 66, 74),
            ("DELETE", "/api/v1/drafts/81", 200, 52, 80),
            ("GET", "/api/v1/tariffs", nil, nil, 86),
            ("GET", "/api/v1/objects?page=2&size=20", 200, 104, 92),
            ("GET", "/api/v1/dashboard/summary", 200, 3620, 99),
            ("GET", "/api/v1/profile/me", 200, 71, 105),
            ("POST", "/api/v1/events", 200, 88, 111),
        ]
        return specs.enumerated().map { index, spec in
            let url = "https://toza-hudud.uz\(spec.1)"
            var log = NetworkLog(
                key: "k\(index)",
                method: spec.0,
                url: url,
                api: spec.1,
                responseCode: spec.2,
                durationMs: spec.3,
                ts: (now.timeIntervalSince1970 - spec.4) * 1000
            )
            log.source = "logcat"
            log.packageName = "uz.realsoft.cleanarea"
            log.serial = "V2202"
            log.deviceModel = "Vivo V2202"
            log.responseHeaders = ["content-type": "application/json; charset=utf-8"]
            log.requestHeaders = ["content-type": "application/json"]
            if spec.2 == nil { log.error = "Unable to resolve host \"toza-hudud.uz\"" }
            if index == 0 {
                log.feature = "auth"
                log.requestBody = "{\"phone\":\"998901234567\",\"password\":\"••••\"}"
                log.responseBody = Self.loginBody
            } else {
                log.responseBody = "{\"status\":\"OK\",\"items\":[1,2,3]}"
            }
            return log
        }
    }

    private func store(_ logs: [NetworkLog]) -> LogStore {
        let s = LogStore()
        s.hideNoise = false
        s.followLatest = true
        s.slowOnly = false
        s.errorsOnly = false
        s.favoritesOnly = false
        s.status = .all
        s.selectedMethod = "ALL"
        s.selectedAppId = "all"
        s.selectedSerial = nil
        s.query = ""
        s.redactEnabled = false
        s.devices = [ConnectedDevice(serial: "V2202", model: "Vivo V2202"), ConnectedDevice(serial: "PX7", model: "Pixel 7")]
        for log in logs { s.liveByKey[log.key] = log }
        s.rebuildFromLive()
        s.selectedKey = logs.first?.key
        s.detailTab = .response
        s.connection = .live
        s.isLoading = false
        return s
    }

    private func window(_ s: LogStore) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach([0xFF5F57, 0xFEBC2E, 0x28C840], id: \.self) { hex in
                        Circle().fill(Color(nsColor: NSColor(rgbHex: hex))).frame(width: 12, height: 12)
                    }
                }
                .padding(.trailing, 18)
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(LogXTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(LogXTheme.chipOn, in: RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous))
                ToolbarTitle(scopeTitle: "Barcha qurilmalar · Barcha ilovalar")
                Spacer(minLength: 12)
                ToolbarActions()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(LogXTheme.chrome)
            .overlay(alignment: .bottom) { Rectangle().fill(LogXTheme.line).frame(height: 1) }
            ContentView()
        }
        .environmentObject(s)
    }

    private func render(appearance: NSAppearance.Name, name: String, size: CGSize = CGSize(width: 1440, height: 900), hoverPath: String? = nil) throws -> NSBitmapImageRep {
        LogXFonts.register(directory: Self.root.appendingPathComponent("Resources/Fonts"))
        XCTAssertTrue(LogXFonts.isAvailable(.mono))
        XCTAssertTrue(LogXFonts.isAvailable(.ui))
        UserDefaults.standard.set(true, forKey: "logx.sidebarVisible")
        UserDefaults.standard.set(false, forKey: "logx.detailHeaderCollapsed")
        UserDefaults.standard.set(false, forKey: "logx.treeBody")
        UserDefaults.standard.set(true, forKey: "logx.prettyBody")
        let s = store(sampleLogs(now: Date()))
        if let hoverPath {
            s.rowHover.key = s.visibleLogs.first { $0.url.contains(hoverPath) }?.key
            XCTAssertNotNil(s.rowHover.key)
        }
        let host = NSHostingView(rootView: window(s).frame(width: size.width, height: size.height))
        host.appearance = NSAppearance(named: appearance)
        host.frame = CGRect(origin: .zero, size: size)
        let offscreen = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        offscreen.isReleasedWhenClosed = false
        offscreen.appearance = NSAppearance(named: appearance)
        offscreen.contentView = host
        defer { offscreen.contentView = nil }
        let deadline = Date().addingTimeInterval(1.6)
        while Date() < deadline {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            host.cacheDisplay(in: host.bounds, to: rep)
        }
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let dir = Self.root.appendingPathComponent(".screenshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try png.write(to: dir.appendingPathComponent("\(name).png"))
        return rep
    }

    private func pixelHex(_ rep: NSBitmapImageRep, x: Int, y: Int) -> Int {
        let scaleX = Double(rep.pixelsWide) / 1440
        let scaleY = Double(rep.pixelsHigh) / 900
        guard let c = rep.colorAt(x: Int(Double(x) * scaleX), y: Int(Double(y) * scaleY))?.usingColorSpace(.sRGB) else { return -1 }
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return (r << 16) | (g << 8) | b
    }

    private func assertNear(_ actual: Int, _ expected: Int, _ label: String, tolerance: Int = 6) {
        let parts = [16, 8, 0].map { abs(((actual >> $0) & 0xFF) - ((expected >> $0) & 0xFF)) }
        XCTAssertTrue(parts.allSatisfy { $0 <= tolerance }, "\(label): \(String(format: "%06X", actual)) != \(String(format: "%06X", expected))")
    }

    func testOsiloskopWindowRendersInDarkAndLight() throws {
        for (appearance, isDark, name) in [(NSAppearance.Name.darkAqua, true, "osiloskop-dark"), (.aqua, false, "osiloskop-light")] {
            let rep = try render(appearance: appearance, name: name)
            XCTAssertGreaterThanOrEqual(rep.pixelsWide, 1440)
            assertNear(pixelHex(rep, x: 6, y: 600), LogXPalette.chrome.hex(isDark: isDark), "\(name) rail chrome")
            assertNear(pixelHex(rep, x: 700, y: 20), LogXPalette.chrome.hex(isDark: isDark), "\(name) toolbar chrome")
            assertNear(pixelHex(rep, x: 900, y: 893), LogXPalette.chrome.hex(isDark: isDark), "\(name) status bar chrome")
        }
    }

    func testNarrowWindowKeepsDetailMetaReadable() throws {
        let rep = try render(appearance: .darkAqua, name: "osiloskop-narrow", size: CGSize(width: 1100, height: 760))
        XCTAssertGreaterThanOrEqual(rep.pixelsWide, 1100)
    }

    func testSelectedRowBarSitsOnListEdge() throws {
        let rep = try render(appearance: .darkAqua, name: "osiloskop-dark")
        let hits = (230...300).filter { y in
            let c = pixelHex(rep, x: 57, y: y)
            let r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF
            return g > 150 && g > r + 40 && g > b + 40
        }
        XCTAssertFalse(hits.isEmpty, "selected row accent bar is not flush with the list edge at x=57")
    }

    func testHoveredRowFillReachesListEdge() throws {
        let rep = try render(appearance: .darkAqua, name: "osiloskop-hover", hoverPath: "/api/v1/objects")
        let brightness: (Int) -> Int = { (($0 >> 16) & 0xFF) + (($0 >> 8) & 0xFF) + ($0 & 0xFF) }
        let hovered = pixelHex(rep, x: 57, y: 320)
        let idle = pixelHex(rep, x: 57, y: 375)
        XCTAssertGreaterThanOrEqual(brightness(hovered) - brightness(idle), 9, "hover fill starts inside the cell inset: \(String(format: "%06X", hovered)) vs \(String(format: "%06X", idle))")
    }
}
