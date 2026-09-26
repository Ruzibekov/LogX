import AppKit
import SwiftUI
import LogXCore

struct LogXHexPair: Equatable, Sendable {
    let dark: Int
    let light: Int

    func hex(isDark: Bool) -> Int { isDark ? dark : light }
}

enum LogXPalette {
    static let bg = LogXHexPair(dark: 0x0D1012, light: 0xEEF1EF)
    static let panel = LogXHexPair(dark: 0x13171A, light: 0xF6F8F6)
    static let panel2 = LogXHexPair(dark: 0x1A2024, light: 0xE2E7E3)
    static let well = LogXHexPair(dark: 0x090B0C, light: 0xF3F6F4)
    static let line = LogXHexPair(dark: 0x1E252A, light: 0xCFD8D2)
    static let divider = LogXHexPair(dark: 0x161B1F, light: 0xE1E7E3)
    static let chrome = LogXHexPair(dark: 0x0A0C0E, light: 0xE6EBE7)

    static let text = LogXHexPair(dark: 0xE4EAE6, light: 0x0E1411)
    static let text2 = LogXHexPair(dark: 0xA9B4AD, light: 0x36433B)
    static let muted = LogXHexPair(dark: 0x6B7770, light: 0x5D6A62)
    static let muted2 = LogXHexPair(dark: 0x4F5C55, light: 0x7C8981)

    static let accent = LogXHexPair(dark: 0x3FCF6E, light: 0x16873F)
    static let onAccent = LogXHexPair(dark: 0x04140A, light: 0xF4FBF6)
    static let accentLight = LogXHexPair(dark: 0x7BE09C, light: 0x16873F)
    static let ok = LogXHexPair(dark: 0x3FCF6E, light: 0x16873F)
    static let warn = LogXHexPair(dark: 0xE9B949, light: 0x9A6A00)
    static let err = LogXHexPair(dark: 0xF2685F, light: 0xC2362D)
    static let replay = LogXHexPair(dark: 0x9C8CF0, light: 0x6B5BD0)
    static let barTrack = LogXHexPair(dark: 0x1E2A24, light: 0xC9D6CD)
    static let methodGet = LogXHexPair(dark: 0x62B3F5, light: 0x1A5FA8)
    static let methodPost = LogXHexPair(dark: 0xF29A55, light: 0x93430A)
    static let methodPut = LogXHexPair(dark: 0xB79CF5, light: 0x6A45C4)
    static let methodPatch = LogXHexPair(dark: 0x4FD1C5, light: 0x0B6560)
    static let methodDelete = LogXHexPair(dark: 0xF2685F, light: 0xA8281F)

    static let jsonKey = LogXHexPair(dark: 0x9FE8B8, light: 0x0F6B34)
    static let jsonString = LogXHexPair(dark: 0xE4EAE6, light: 0x0E1411)
    static let jsonNumber = LogXHexPair(dark: 0xE9B949, light: 0x8A5A00)
    static let jsonBoolNull = LogXHexPair(dark: 0xF2685F, light: 0xB42318)
    static let jsonPunct = LogXHexPair(dark: 0x4F5C55, light: 0x6B7770)
    static let jsonPlain = LogXHexPair(dark: 0xE4EAE6, light: 0x0E1411)
}

enum LogXRadius {
    static let control: CGFloat = 6
    static let chip: CGFloat = 5
    static let avatar: CGFloat = 10
}

enum StatusTone: Equatable {
    case accent
    case warn
    case err
    case neutral
    case muted
    case text

    static func of(_ cls: LogXCore.StatusClass) -> StatusTone {
        switch cls {
        case .ok2xx: return .accent
        case .redirect3xx: return .neutral
        case .err4xx: return .warn
        case .err5xx: return .err
        case .net: return .muted
        case .pending: return .neutral
        case .all: return .text
        }
    }

    var hex: LogXHexPair {
        switch self {
        case .accent: return LogXPalette.ok
        case .warn: return LogXPalette.warn
        case .err: return LogXPalette.err
        case .neutral: return LogXPalette.text2
        case .muted: return LogXPalette.muted
        case .text: return LogXPalette.text
        }
    }
}

enum LogXTheme {
    static let bg = color(LogXPalette.bg)
    static let panel = color(LogXPalette.panel)
    static let panel2 = color(LogXPalette.panel2)
    static let well = color(LogXPalette.well)
    static let line = color(LogXPalette.line)
    static let divider = color(LogXPalette.divider)
    static let chrome = color(LogXPalette.chrome)
    static let chromeNS = dynamicNS(LogXPalette.chrome)

    static let text = color(LogXPalette.text)
    static let text2 = color(LogXPalette.text2)
    static let muted = color(LogXPalette.muted)
    static let muted2 = color(LogXPalette.muted2)

    static let accent = color(LogXPalette.accent)
    static let onAccent = color(LogXPalette.onAccent)
    static let accentLight = color(LogXPalette.accentLight)
    static let ok = color(LogXPalette.ok)
    static let warn = color(LogXPalette.warn)
    static let err = color(LogXPalette.err)
    static let replay = color(LogXPalette.replay)
    static let barTrack = color(LogXPalette.barTrack)

    static let method = text2
    static let net = muted

    static let selection = accent.opacity(0.07)
    static let selectionEdge = accent
    static let chipOn = accent.opacity(0.12)
    static let chipOnEdge = accent.opacity(0.45)
    static let focusRing = accent.opacity(0.75)

    static func methodColor(_ method: String) -> Color {
        color(MethodTone.of(method).hex)
    }

    static func status(_ cls: LogXCore.StatusClass) -> Color {
        color(StatusTone.of(cls).hex)
    }

    static func statusTint(_ cls: LogXCore.StatusClass) -> Color {
        status(cls).opacity(0.12)
    }

    static func dynamicNS(_ pair: LogXHexPair) -> NSColor {
        dynamicNS(dark: pair.dark, light: pair.light)
    }

    static func dynamicNS(dark: Int, light: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgbHex: isDark ? dark : light)
        }
    }

    static func color(_ pair: LogXHexPair) -> Color {
        Color(nsColor: dynamicNS(pair))
    }

    static func dynamic(dark: Int, light: Int) -> Color {
        Color(nsColor: dynamicNS(dark: dark, light: light))
    }
}

enum LogXContrast {
    static func luminance(_ hex: Int) -> Double {
        func channel(_ value: Int) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = channel((hex >> 16) & 0xFF)
        let g = channel((hex >> 8) & 0xFF)
        let b = channel(hex & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    static func ratio(_ a: Int, _ b: Int) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

extension NSColor {
    convenience init(rgbHex: Int) {
        self.init(
            srgbRed: CGFloat((rgbHex >> 16) & 0xFF) / 255,
            green: CGFloat((rgbHex >> 8) & 0xFF) / 255,
            blue: CGFloat(rgbHex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct ConnectionDot: View {
    var tint: Color
    var pulsing: Bool

    var body: some View {
        LiveDot(tint: tint, pulsing: pulsing, size: 6)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }
}
