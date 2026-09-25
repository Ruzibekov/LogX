import XCTest
import SwiftUI
import LogXCore
@testable import LogX

final class OsiloskopThemeTests: XCTestCase {
    func testDarkAndLightTokensMatchDirectionB() {
        let expected: [(LogXHexPair, Int, Int)] = [
            (LogXPalette.bg, 0x0D1012, 0xEEF1EF),
            (LogXPalette.panel, 0x13171A, 0xF6F8F6),
            (LogXPalette.panel2, 0x1A2024, 0xE2E7E3),
            (LogXPalette.well, 0x090B0C, 0xF3F6F4),
            (LogXPalette.line, 0x1E252A, 0xCFD8D2),
            (LogXPalette.divider, 0x161B1F, 0xE1E7E3),
            (LogXPalette.chrome, 0x0A0C0E, 0xE6EBE7),
            (LogXPalette.text, 0xE4EAE6, 0x0E1411),
            (LogXPalette.text2, 0xA9B4AD, 0x36433B),
            (LogXPalette.muted, 0x6B7770, 0x5D6A62),
            (LogXPalette.muted2, 0x4F5C55, 0x7C8981),
            (LogXPalette.accent, 0x3FCF6E, 0x16873F),
            (LogXPalette.onAccent, 0x04140A, 0xF4FBF6),
            (LogXPalette.accentLight, 0x7BE09C, 0x16873F),
            (LogXPalette.ok, 0x3FCF6E, 0x16873F),
            (LogXPalette.warn, 0xE9B949, 0x9A6A00),
            (LogXPalette.err, 0xF2685F, 0xC2362D),
            (LogXPalette.replay, 0x9C8CF0, 0x6B5BD0),
            (LogXPalette.barTrack, 0x1E2A24, 0xC9D6CD),
        ]
        for (pair, dark, light) in expected {
            XCTAssertEqual(pair.hex(isDark: true), dark, String(format: "%06X", dark))
            XCTAssertEqual(pair.hex(isDark: false), light, String(format: "%06X", light))
        }
    }

    func testJSONSyntaxInksPerAppearance() {
        XCTAssertEqual(JSONHighlighter.hex(.key), LogXHexPair(dark: 0x9FE8B8, light: 0x0F6B34))
        XCTAssertEqual(JSONHighlighter.hex(.string), LogXHexPair(dark: 0xE4EAE6, light: 0x0E1411))
        XCTAssertEqual(JSONHighlighter.hex(.number), LogXHexPair(dark: 0xE9B949, light: 0x8A5A00))
        XCTAssertEqual(JSONHighlighter.hex(.boolNull), LogXHexPair(dark: 0xF2685F, light: 0xB42318))
        XCTAssertEqual(JSONHighlighter.hex(.punct), LogXHexPair(dark: 0x4F5C55, light: 0x6B7770))
        XCTAssertEqual(JSONHighlighter.hex(.plain), LogXHexPair(dark: 0xE4EAE6, light: 0x0E1411))
    }

    func testDynamicColorResolvesPerAppearance() {
        let color = LogXTheme.dynamicNS(LogXPalette.accent)
        var dark = NSColor.clear
        var light = NSColor.clear
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance { dark = color.usingColorSpace(.sRGB)! }
        NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance { light = color.usingColorSpace(.sRGB)! }
        XCTAssertEqual(Int((dark.greenComponent * 255).rounded()), 0xCF)
        XCTAssertEqual(Int((light.greenComponent * 255).rounded()), 0x87)
    }

    func testStatusClassMapsToTone() {
        XCTAssertEqual(StatusTone.of(.ok2xx), .accent)
        XCTAssertEqual(StatusTone.of(.redirect3xx), .neutral)
        XCTAssertEqual(StatusTone.of(.err4xx), .warn)
        XCTAssertEqual(StatusTone.of(.err5xx), .err)
        XCTAssertEqual(StatusTone.of(.net), .muted)
        XCTAssertEqual(StatusTone.of(.all), .text)
        XCTAssertEqual(StatusTone.accent.hex, LogXPalette.ok)
        XCTAssertEqual(StatusTone.warn.hex, LogXPalette.warn)
        XCTAssertEqual(StatusTone.err.hex, LogXPalette.err)
        XCTAssertEqual(StatusTone.muted.hex, LogXPalette.muted)
    }

    func testTextContrastHoldsInBothAppearances() {
        for isDark in [true, false] {
            let bg = LogXPalette.bg.hex(isDark: isDark)
            let chrome = LogXPalette.chrome.hex(isDark: isDark)
            XCTAssertGreaterThanOrEqual(LogXContrast.ratio(LogXPalette.text.hex(isDark: isDark), bg), 7)
            XCTAssertGreaterThanOrEqual(LogXContrast.ratio(LogXPalette.text2.hex(isDark: isDark), bg), 7)
            XCTAssertGreaterThanOrEqual(LogXContrast.ratio(LogXPalette.muted.hex(isDark: isDark), bg), 4)
            XCTAssertGreaterThanOrEqual(LogXContrast.ratio(LogXPalette.muted.hex(isDark: isDark), chrome), 4)
            XCTAssertGreaterThanOrEqual(LogXContrast.ratio(LogXPalette.accent.hex(isDark: isDark), bg), 3)
            XCTAssertGreaterThanOrEqual(LogXContrast.ratio(LogXPalette.err.hex(isDark: isDark), bg), 4.5)
            XCTAssertGreaterThanOrEqual(
                LogXContrast.ratio(LogXPalette.onAccent.hex(isDark: isDark), LogXPalette.accent.hex(isDark: isDark)),
                4.3
            )
        }
        XCTAssertEqual(LogXContrast.ratio(0xFFFFFF, 0x000000), 21, accuracy: 0.01)
        XCTAssertEqual(LogXContrast.ratio(0x777777, 0x777777), 1, accuracy: 0.0001)
    }

    func testRadiiFollowSpec() {
        XCTAssertEqual(LogXRadius.control, 6)
        XCTAssertEqual(LogXRadius.chip, 5)
        XCTAssertEqual(LogXRadius.avatar, 10)
        XCTAssertEqual(DeviceRail.avatar, 38)
    }

    func testMotionBudgetsAndReduceMotionGate() {
        XCTAssertLessThanOrEqual(LogXMotion.rowInsertDuration, 0.18)
        XCTAssertLessThanOrEqual(LogXMotion.statusCrossfadeDuration, 0.2)
        XCTAssertGreaterThanOrEqual(LogXMotion.livePulseDuration, 1.4)
        XCTAssertNil(LogXMotion.gated(.easeOut(duration: 0.1), reduce: true))
        XCTAssertNotNil(LogXMotion.gated(.easeOut(duration: 0.1), reduce: false))
        XCTAssertNil(LogXMotion.press(reduce: true))
    }

    func testRowEntranceOnlyForJustArrivedRequests() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        XCTAssertTrue(RowEntrance.shouldAnimate(ts: 1_789_000_000_000 - 500, now: now))
        XCTAssertTrue(RowEntrance.shouldAnimate(ts: 1_789_000_000 - 1, now: now))
        XCTAssertFalse(RowEntrance.shouldAnimate(ts: 1_789_000_000_000 - 5_000, now: now))
        XCTAssertFalse(RowEntrance.shouldAnimate(ts: 1_789_000_000_000 + 60_000, now: now))
        XCTAssertFalse(RowEntrance.shouldAnimate(ts: nil, now: now))
    }

    func testURLStyleSplitsPathFromHostAndQuery() {
        let runs = URLStyle.runs("https://toza-hudud.uz/api/v1/objects?page=1&size=20")
        XCTAssertEqual(runs.map(\.text), ["https://toza-hudud.uz", "/api/v1/objects", "?page=1&size=20"])
        XCTAssertEqual(runs.map(\.ink), [.muted, .primary, .muted])
        let bare = URLStyle.runs("/api/v1/auth/login")
        XCTAssertEqual(bare.map(\.ink), [.primary])
        XCTAssertEqual(bare.map(\.text).joined(), "/api/v1/auth/login")
        XCTAssertTrue(URLStyle.runs("").isEmpty)
    }

    func testDetailFactsListOnlyFieldsPresentInLog() {
        var log = NetworkLog(key: "k", method: "POST", url: "https://h.uz/a", api: "/a", responseCode: 200, durationMs: 184, ts: 1_789_000_000_000)
        log.feature = "auth"
        let full = DetailFacts.make(log: log, sizeLabel: "1.2 KB", collapsed: false)
        XCTAssertEqual(full.map(\.label), ["Davomiylik", "Hajm", "Vaqt", "Modul"])
        XCTAssertEqual(full.first?.value, "184 ms")
        XCTAssertEqual(full.last?.value, "auth")
        XCTAssertEqual(DetailFacts.make(log: log, sizeLabel: "1 B", collapsed: true).map(\.label), ["Davomiylik", "Hajm", "Vaqt"])
        log.durationMs = nil
        log.feature = nil
        log.moduleName = "Kirish"
        XCTAssertEqual(DetailFacts.make(log: log, sizeLabel: "0 B", collapsed: false).map(\.label), ["Hajm", "Vaqt"])
        log.feature = "auth"
        XCTAssertEqual(DetailFacts.moduleLabel(log), "Kirish")
    }

    func testStatusCodeLabelAndReasonSizing() {
        let ok = NetworkLog(key: "a", method: "GET", url: "https://h.uz", api: "/", responseCode: 200, durationMs: 1, ts: nil)
        let net = NetworkLog(key: "b", method: "GET", url: "https://h.uz", api: "/", responseCode: nil, durationMs: nil, ts: nil)
        XCTAssertEqual(DetailFacts.codeLabel(ok), "200")
        XCTAssertEqual(DetailFacts.codeLabel(net), "NET")
        XCTAssertTrue(DetailFacts.reasonIsShort("OK"))
        XCTAssertTrue(DetailFacts.reasonIsShort("Unauthorized"))
        XCTAssertFalse(DetailFacts.reasonIsShort("Internal Server Error"))
    }
}
