import SwiftUI

enum LogXButtonKind: Equatable {
    case primary
    case outline
    case tinted
    case quiet
}

struct LogXButtonStyle: ButtonStyle {
    var kind: LogXButtonKind
    var height: CGFloat = 30
    var horizontalPadding: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        LogXButtonBody(configuration: configuration, kind: kind, height: height, horizontalPadding: horizontalPadding)
    }
}

private struct LogXButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: LogXButtonKind
    let height: CGFloat
    let horizontalPadding: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    var body: some View {
        let reduce = reduceMotion || LogXMotion.reduceMotion
        let shape = RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
        configuration.label
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: height, minHeight: height, maxHeight: height)
            .background(shape.fill(fill))
            .overlay(shape.stroke(edge, lineWidth: 1))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(reduce ? 1 : (configuration.isPressed ? LogXMotion.pressScale : 1))
            .brightness(configuration.isPressed && kind == .primary ? -0.06 : 0)
            .animation(LogXMotion.press(reduce: reduce), value: configuration.isPressed)
            .animation(reduce ? nil : LogXMotion.hover, value: hovered)
            .onHover { hovered = $0 && isEnabled }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return LogXTheme.onAccent
        case .tinted: return LogXTheme.accent
        case .outline, .quiet: return hovered ? LogXTheme.text : LogXTheme.text2
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: return LogXTheme.accent
        case .tinted: return LogXTheme.chipOn
        case .outline: return hovered ? LogXTheme.panel2 : Color.clear
        case .quiet: return hovered ? LogXTheme.panel2 : Color.clear
        }
    }

    private var edge: Color {
        switch kind {
        case .primary: return Color.clear
        case .tinted: return LogXTheme.chipOnEdge
        case .outline: return LogXTheme.line
        case .quiet: return Color.clear
        }
    }
}
