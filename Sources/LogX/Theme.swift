import AppKit
import SwiftUI
import LogXCore

enum LogXTheme {
    static let bg = dynamic(dark: 0x0C0E11, light: 0xEFF2F6)
    static let panel = dynamic(dark: 0x131619, light: 0xF8FAFC)
    static let panel2 = dynamic(dark: 0x181C21, light: 0xE7ECF2)
    static let well = dynamic(dark: 0x0A0C0F, light: 0xF2F5F9)
    static let line = dynamic(dark: 0x23282F, light: 0xDDE2E8)
    static let divider = dynamic(dark: 0x1B1F25, light: 0xE7EBF0)

    static let text = dynamic(dark: 0xECEFF3, light: 0x141821)
    static let text2 = dynamic(dark: 0xA7B0BC, light: 0x3F4855)
    static let muted = dynamic(dark: 0x6E7885, light: 0x59626F)
    static let muted2 = dynamic(dark: 0x4C545F, light: 0x737C89)

    static let accent = dynamic(dark: 0x1FB6D4, light: 0x0A6073)
    static let onAccent = dynamic(dark: 0x06222A, light: 0xF8FAFC)
    static let accentLight = dynamic(dark: 0x63D3E8, light: 0x0A6073)
    static let ok = dynamic(dark: 0x2FBF71, light: 0x1A7A44)
    static let warn = dynamic(dark: 0xE0A23C, light: 0xA96B0C)
    static let err = dynamic(dark: 0xE5534B, light: 0xC0392F)
    static let replay = dynamic(dark: 0x8D7BEA, light: 0x6B5BD0)
    static let barTrack = dynamic(dark: 0x2B424D, light: 0xB7C4D0)

    static let method = text2
    static let net = muted

    static let selection = accent.opacity(0.10)
    static let selectionEdge = accent.opacity(0.32)
    static let chipOn = accent.opacity(0.14)
    static let chipOnEdge = accent.opacity(0.45)
    static let focusRing = accent.opacity(0.75)

    /// Metod rang bilan emas, vazn bilan ajratiladi; faqat DELETE ogohlantiradi.
    static func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "DELETE": return err
        case "GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS": return text2
        default: return muted
        }
    }

    static func status(_ cls: LogXCore.StatusClass) -> Color {
        switch cls {
        case .ok2xx: return ok
        case .redirect3xx: return text2
        case .err4xx: return warn
        case .err5xx: return err
        case .net: return net
        case .all: return text
        }
    }

    static func statusTint(_ cls: LogXCore.StatusClass) -> Color {
        status(cls).opacity(0.13)
    }

    static func dynamicNS(dark: Int, light: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgbHex: isDark ? dark : light)
        }
    }

    static func dynamic(dark: Int, light: Int) -> Color {
        Color(nsColor: dynamicNS(dark: dark, light: light))
    }
}

enum LogXType {
    static let caption: CGFloat = 10
    static let meta: CGFloat = 12
    static let body: CGFloat = 13
    static let title: CGFloat = 14
    static let display: CGFloat = 22

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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
        Image(systemName: pulsing ? "bolt.horizontal.circle.fill" : "circle")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
    }
}
