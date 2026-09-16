import SwiftUI

struct ActionPillButton: View {
    var title: String
    var icon: String? = nil
    var shortcut: [ShortcutGlyph.Part]? = nil
    var isPrimary: Bool = false
    var help: String? = nil
    var label: String? = nil
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                }
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 11, weight: isPrimary ? .semibold : .medium))
                        .lineLimit(1)
                }
                if let shortcut {
                    ShortcutGlyph(parts: shortcut)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isPrimary ? (hovered ? LogXTheme.well.opacity(0.85) : LogXTheme.well) : (hovered ? LogXTheme.panel2 : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isPrimary ? (hovered ? LogXTheme.accent : LogXTheme.line) : (hovered ? LogXTheme.line : Color.clear), lineWidth: 1)
            )
            .foregroundStyle(isPrimary ? LogXTheme.accentLight : (isEnabled ? (hovered ? LogXTheme.text : LogXTheme.muted) : LogXTheme.muted2))
            .animation(.easeOut(duration: 0.12), value: hovered)
        }
        .buttonStyle(LogXPressStyle())
        .fixedSize(horizontal: true, vertical: false)
        .onHover { hovered = $0 }
        .help(help ?? title)
        .accessibilityLabel(label ?? title)
    }
}
