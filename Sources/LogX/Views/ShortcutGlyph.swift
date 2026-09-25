import SwiftUI

struct ShortcutGlyph: View {
    enum Part: Hashable {
        case symbol(String)
        case letter(String)
    }

    var parts: [Part]
    var compact: Bool = true

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: compact ? 8 : 9, weight: .bold))
                case .letter(let text):
                    Text(text)
                        .font(LogXType.mono(compact ? 8.5 : 9, .semibold))
                }
            }
        }
        .foregroundStyle(LogXTheme.muted)
        .padding(.horizontal, compact ? 4.5 : 5)
        .padding(.vertical, compact ? 2 : 2.5)
        .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(LogXTheme.line, lineWidth: 1)
        )
        .fixedSize()
        .accessibilityLabel(label)
    }

    private var label: String {
        parts.map { part in
            switch part {
            case .symbol("command"): return "Command"
            case .symbol("shift"): return "Shift"
            case .symbol("chevron.up.chevron.down"): return "Yuqoriga pastga"
            case .symbol(let name): return name
            case .letter(let text): return text
            }
        }.joined(separator: " ")
    }
}

struct LogXPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let reduce = reduceMotion || LogXMotion.reduceMotion
        return configuration.label
            .scaleEffect(reduce ? 1 : (configuration.isPressed ? LogXMotion.pressScale : 1))
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(LogXMotion.press(reduce: reduce), value: configuration.isPressed)
    }
}
