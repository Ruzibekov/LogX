import XCTest
import SwiftUI
import AppKit
@testable import LogX

final class MethodBadgeTests: XCTestCase {
    private func channel(_ v: Int) -> Double {
        let c = Double(v) / 255
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private func rgb(_ hex: Int) -> (Int, Int, Int) { ((hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF) }

    private func luminance(_ c: (Int, Int, Int)) -> Double {
        0.2126 * channel(c.0) + 0.7152 * channel(c.1) + 0.0722 * channel(c.2)
    }

    private func blend(_ fg: Int, over bg: Int, alpha: Double) -> (Int, Int, Int) {
        let f = rgb(fg), b = rgb(bg)
        func mix(_ x: Int, _ y: Int) -> Int { Int((Double(x) * alpha + Double(y) * (1 - alpha)).rounded()) }
        return (mix(f.0, b.0), mix(f.1, b.1), mix(f.2, b.2))
    }

    private func contrast(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    func testCommonMethodsHaveDistinctColors() {
        let methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]
        let tones = methods.map { MethodTone.of($0) }
        XCTAssertEqual(Set(tones.map(\.hex.dark)).count, methods.count)
        XCTAssertEqual(Set(tones.map(\.hex.light)).count, methods.count)
        XCTAssertEqual(MethodTone.of("get"), MethodTone.of("GET"))
        XCTAssertEqual(MethodTone.of("DELETE").hex.dark, LogXPalette.err.dark)
        XCTAssertEqual(MethodTone.of("OPTIONS").hex, LogXPalette.text2)
        XCTAssertEqual(MethodTone.of("").hex, LogXPalette.text2)
    }

    func testMethodColorsDoNotReuseStatusColors() {
        let status = [LogXPalette.ok, LogXPalette.warn, LogXPalette.accent]
        for method in ["GET", "POST", "PUT", "PATCH"] {
            XCTAssertFalse(status.contains(MethodTone.of(method).hex), method)
        }
    }

    func testMethodTextReadableOnItsCardInBothThemes() {
        for method in ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"] {
            let hex = MethodTone.of(method).hex
            for (isDark, bg) in [(true, LogXPalette.bg.dark), (false, LogXPalette.bg.light), (true, LogXPalette.panel.dark), (false, LogXPalette.panel.light)] {
                let fg = hex.hex(isDark: isDark)
                let card = blend(fg, over: bg, alpha: MethodBadge.fillOpacity)
                XCTAssertGreaterThanOrEqual(contrast(rgb(fg), card), 4.5, "\(method) \(isDark ? "dark" : "light")")
            }
        }
    }

    @MainActor
    func testMethodBadgesRender() throws {
        let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
        for (scheme, name) in [(ColorScheme.dark, "dark"), (.light, "light")] {
            let view = HStack(spacing: 8) { ForEach(methods, id: \.self) { MethodBadge(method: $0) } }
                .padding(16)
                .background(LogXTheme.bg)
                .environment(\.colorScheme, scheme)
            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            host.frame = CGRect(origin: .zero, size: host.fittingSize)
            host.layoutSubtreeIfNeeded()
            let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".screenshots")
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("render-method-badges-\(name).png"))
            XCTAssertGreaterThan(host.fittingSize.width, 200)
        }
    }

    func testFilterBarMethodChipsUseMethodColors() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bar = try String(contentsOf: root.appendingPathComponent("Sources/LogX/Views/RequestFilterBar.swift"), encoding: .utf8)
        XCTAssertTrue(bar.contains("let tint = LogXTheme.methodColor(method)"), "filter bar metod chiplari metod rangini olishi kerak")
        XCTAssertTrue(bar.contains("FilterChipFrame(active: active, tint: tint, idleInk: tint)"), "tanlanmagan chip ham rangli bo'lishi kerak")
    }

    @MainActor
    func testFilterBarMethodChipsRender() throws {
        for (scheme, name) in [(ColorScheme.dark, "dark"), (.light, "light")] {
            let store = LogStore()
            store.selectedMethod = "POST"
            let size = CGSize(width: 1500, height: 110)
            let view = RequestFilterBar().environmentObject(store)
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, scheme)
            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            host.frame = CGRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".screenshots")
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("render-filterbar-methods-\(name).png"))
        }
    }

    @MainActor
    func testSortMenuMethodSwatchShowsEveryMethodColor() throws {
        let image = MethodSwatch.image
        XCTAssertFalse(image.isTemplate, "menyu rasmni oq-qora qilib yubormasligi uchun template bo'lmasligi kerak")
        XCTAssertEqual(image.size.height, MethodSwatch.dot)
        XCTAssertEqual(MethodSwatch.tones, [.get, .post, .put, .patch, .delete])
        for (appearanceName, isDark) in [(NSAppearance.Name.darkAqua, true), (.aqua, false)] {
            let appearance = try XCTUnwrap(NSAppearance(named: appearanceName))
            let scale: CGFloat = 4
            let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * scale), pixelsHigh: Int(image.size.height * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
            rep.size = image.size
            appearance.performAsCurrentDrawingAppearance {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                image.draw(in: NSRect(origin: .zero, size: image.size))
                NSGraphicsContext.restoreGraphicsState()
            }
            for (i, tone) in MethodSwatch.tones.enumerated() {
                let center = MethodSwatch.center(of: i)
                let color = try XCTUnwrap(rep.colorAt(x: Int(center.x * scale), y: Int((image.size.height - center.y) * scale))?.usingColorSpace(.sRGB))
                let expected = tone.hex.hex(isDark: isDark)
                XCTAssertEqual(Int((color.redComponent * 255).rounded()), (expected >> 16) & 0xFF, accuracy: 6, "\(tone) \(isDark)")
                XCTAssertEqual(Int((color.greenComponent * 255).rounded()), (expected >> 8) & 0xFF, accuracy: 6, "\(tone) \(isDark)")
                XCTAssertEqual(Int((color.blueComponent * 255).rounded()), expected & 0xFF, accuracy: 6, "\(tone) \(isDark)")
            }
            if let png = rep.representation(using: .png, properties: [:]) {
                let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".screenshots")
                try? png.write(to: dir.appendingPathComponent("render-sort-method-swatch-\(isDark ? "dark" : "light").png"))
            }
        }
    }

    func testSortMenuMethodItemCarriesSwatchAndNativeCheckmark() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bar = try String(contentsOf: root.appendingPathComponent("Sources/LogX/Views/RequestFilterBar.swift"), encoding: .utf8)
        XCTAssertTrue(bar.contains("sortItem(\"Metod\", field: .method, swatch: MethodSwatch.image)"), bar)
        XCTAssertTrue(bar.contains("Toggle(isOn:"), "tanlangan saralash belgisi menyuning o'z checkmark ustunida bo'lishi kerak")
    }
}
