import XCTest
import AppKit
import CoreText
import SwiftUI
@testable import LogX

final class OsiloskopFontTests: XCTestCase {
    static var fontsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Fonts")
    }

    private func variation(_ font: NSFont) -> [Int: Double] {
        let raw = CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber] ?? [:]
        return raw.reduce(into: [Int: Double]()) { $0[$1.key.intValue] = $1.value.doubleValue }
    }

    private func unregisterBundledFonts() {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.fontsDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "ttf" {
            CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
        }
        LogXFonts.resetCache()
    }

    func testBundledFontFilesAndLicensesExist() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: Self.fontsDirectory.path).sorted()
        XCTAssertEqual(names, ["Manrope-Variable.ttf", "MartianMono-Variable.ttf", "OFL-Manrope.txt", "OFL-MartianMono.txt"])
        for license in ["OFL-Manrope.txt", "OFL-MartianMono.txt"] {
            let text = try String(contentsOf: Self.fontsDirectory.appendingPathComponent(license), encoding: .utf8)
            XCTAssertTrue(text.contains("SIL Open Font License"), license)
        }
    }

    func testFamilyNamesComeFromTheFontFiles() {
        for (file, family) in [("MartianMono-Variable.ttf", "Martian Mono"), ("Manrope-Variable.ttf", "Manrope")] {
            let url = Self.fontsDirectory.appendingPathComponent(file)
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
            XCTAssertFalse(descriptors.isEmpty, file)
            let families = Set(descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontFamilyNameAttribute) as? String })
            XCTAssertEqual(families, [family], file)
        }
        XCTAssertEqual(LogXFontFamily.mono.rawValue, "Martian Mono")
        XCTAssertEqual(LogXFontFamily.ui.rawValue, "Manrope")
    }

    func testWeightMappingAndClampToAxisRange() {
        XCTAssertEqual(LogXFonts.axisWeight(.ultraLight), 200)
        XCTAssertEqual(LogXFonts.axisWeight(.thin), 100)
        XCTAssertEqual(LogXFonts.axisWeight(.regular), 400)
        XCTAssertEqual(LogXFonts.axisWeight(.semibold), 600)
        XCTAssertEqual(LogXFonts.axisWeight(.black), 800)
        XCTAssertEqual(LogXFonts.clampedWeight(.thin, family: .ui), 200)
        XCTAssertEqual(LogXFonts.clampedWeight(.thin, family: .mono), 100)
        XCTAssertEqual(LogXFonts.variation(family: .mono, weight: .bold), [LogXFonts.weightAxisTag: 700, LogXFonts.widthAxisTag: 100])
        XCTAssertEqual(LogXFonts.variation(family: .ui, weight: .medium), [LogXFonts.weightAxisTag: 500])
    }

    func testFallsBackToSystemFontsWhenNotRegistered() {
        unregisterBundledFonts()
        defer { LogXFonts.register(directory: Self.fontsDirectory) }
        XCTAssertFalse(LogXFonts.isAvailable(.mono))
        XCTAssertNil(LogXFonts.nsFont(.mono, size: 12, weight: .regular))
        let mono = LogXFonts.nsMono(12)
        XCTAssertNotEqual(mono.familyName, "Martian Mono")
        XCTAssertTrue(mono.isFixedPitch)
        XCTAssertNotEqual(LogXFonts.nsUI(12).familyName, "Manrope")
    }

    func testRegisteredVariableWeightsApply() throws {
        LogXFonts.register(directory: Self.fontsDirectory)
        XCTAssertTrue(LogXFonts.isAvailable(.mono))
        XCTAssertTrue(LogXFonts.isAvailable(.ui))
        let hero = try XCTUnwrap(LogXFonts.nsFont(.mono, size: 72, weight: .ultraLight))
        XCTAssertEqual(hero.familyName, "Martian Mono")
        XCTAssertEqual(variation(hero)[LogXFonts.weightAxisTag] ?? 0, 200, accuracy: 0.5)
        XCTAssertEqual(variation(hero)[LogXFonts.widthAxisTag] ?? 0, 100, accuracy: 0.5)
        let bold = try XCTUnwrap(LogXFonts.nsFont(.mono, size: 12, weight: .bold))
        XCTAssertEqual(variation(bold)[LogXFonts.weightAxisTag] ?? 0, 700, accuracy: 0.5)
        let ui = try XCTUnwrap(LogXFonts.nsFont(.ui, size: 13, weight: .heavy))
        XCTAssertEqual(ui.familyName, "Manrope")
        XCTAssertEqual(variation(ui)[LogXFonts.weightAxisTag] ?? 0, 800, accuracy: 0.5)
        XCTAssertGreaterThan(Double(inkCoverage(bold)), Double(inkCoverage(LogXFonts.nsMono(12, .thin))) * 1.5)
    }

    private func inkCoverage(_ font: NSFont) -> Int {
        let size = NSSize(width: 120, height: 30)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSAttributedString(string: "200 OK", attributes: [.font: font, .foregroundColor: NSColor.black]).draw(at: NSPoint(x: 2, y: 6))
        NSGraphicsContext.restoreGraphicsState()
        var inked = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                inked += 1
            }
        }
        return inked
    }
}
