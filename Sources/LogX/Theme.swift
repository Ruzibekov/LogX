import SwiftUI
import LogXCore

enum LogXTheme {
    static let bg = Color(red: 0.059, green: 0.063, blue: 0.071)      // #0F1012
    static let panel = Color(red: 0.082, green: 0.086, blue: 0.098)   // #151619
    static let panel2 = Color(red: 0.110, green: 0.118, blue: 0.133)  // #1C1E22
    static let well = Color(red: 0.071, green: 0.075, blue: 0.086)    // #121316
    static let line = Color(red: 0.169, green: 0.180, blue: 0.204)    // #2B2E34
    static let divider = Color(red: 0.125, green: 0.133, blue: 0.149) // #202226

    static let text = Color(red: 0.949, green: 0.953, blue: 0.961)    // #F2F3F5
    static let text2 = Color(red: 0.788, green: 0.800, blue: 0.824)   // #C9CCD2
    static let muted = Color(red: 0.549, green: 0.569, blue: 0.604)   // #8C919A
    static let muted2 = Color(red: 0.541, green: 0.561, blue: 0.600)  // #8A8F99 (AA 5.8:1 on bg)

    static let accent = Color(red: 0.357, green: 0.553, blue: 0.937)      // #5B8DEF
    static let accentLight = Color(red: 0.541, green: 0.690, blue: 0.961) // #8AB0F5
    static let ok = Color(red: 0.239, green: 0.745, blue: 0.478)          // #3DBE7A
    static let warn = Color(red: 0.878, green: 0.651, blue: 0.231)        // #E0A63B
    static let err = Color(red: 0.933, green: 0.416, blue: 0.439)         // #EE6A70 (AA on 20% tint)
    static let method = accentLight
    static let net = muted

    static let selection = accent.opacity(0.14)
    static let selectionEdge = accent.opacity(0.35)
    static let chipOn = accent.opacity(0.16)
    static let chipOnEdge = accent.opacity(0.45)
    static let focusRing = accent.opacity(0.6)
    static let glow = accent.opacity(0.22)

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
}

struct ConnectionDot: View {
    var tint: Color
    var pulsing: Bool

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            if pulsing {
                Circle()
                    .stroke(tint.opacity(0.4), lineWidth: 2)
                    .frame(width: 13, height: 13)
                    .scaleEffect(pulse ? 1.28 : 1.0)
                    .opacity(pulse ? 0.25 : 0.85)
            }
        }
        .frame(width: 16, height: 16)
        .onAppear {
            if pulsing, !reduceMotion { pulse = true }
        }
        .onChange(of: pulsing) { _, on in
            pulse = on && !reduceMotion
        }
        .animation(
            pulsing && !reduceMotion
                ? .spring(response: 0.9, dampingFraction: 0.42).repeatForever(autoreverses: true)
                : .spring(response: 0.28, dampingFraction: 0.86),
            value: pulse
        )
        .accessibilityHidden(true)
    }
}
