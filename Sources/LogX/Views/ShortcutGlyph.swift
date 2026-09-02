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
                        .font(.system(size: compact ? 9 : 9.5, weight: .semibold))
                }
            }
        }
        .foregroundStyle(LogXTheme.muted2)
        .padding(.horizontal, compact ? 4.5 : 5)
        .padding(.vertical, compact ? 2 : 2.5)
        .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 3.5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
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
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.16, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}
