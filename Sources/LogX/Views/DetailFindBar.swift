import SwiftUI
import LogXCore

struct DetailFindBar: View {
    @Binding var query: String
    @Binding var index: Int
    var matchCount: Int
    @FocusState private var focused: Bool

    private var label: String {
        if matchCount == 0 { return "0" }
        let idx = min(max(index, 0), matchCount - 1)
        return "\(idx + 1)/\(matchCount)"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LogXTheme.muted)
            TextField("Tana ichida qidirish", text: $query)
                .accessibilityLabel("JSON ichida topish")
                .focused($focused)
                .textFieldStyle(.plain)
                .font(LogXType.ui(LogXType.meta))
                .foregroundStyle(LogXTheme.text)
                .onChange(of: query) { _, _ in
                    index = 0
                }
                .onSubmit {
                    step(reverse: false)
                }
                .onExitCommand {
                    if query.isEmpty {
                        focused = false
                    } else {
                        query = ""
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: LogXNotice.focusDetailFind)) { _ in
                    focused = true
                }
            Text(label)
                .font(LogXType.mono(LogXType.caption, .bold))
                .foregroundStyle(matchCount == 0 ? LogXTheme.muted2 : LogXTheme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(matchCount == 0 ? LogXTheme.well : LogXTheme.chipOn))
                .animation(LogXMotion.snappy, value: label)
            stepButton(icon: "chevron.up", help: "Oldingi (⇧⌘G)", label: "Oldingi topilma", reverse: true)
                .keyboardShortcut("g", modifiers: [.command, .shift])
            stepButton(icon: "chevron.down", help: "Keyingi (⌘G)", label: "Keyingi topilma", reverse: false)
                .keyboardShortcut("g", modifiers: .command)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous).fill(LogXTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous).stroke(focused ? LogXTheme.focusRing : LogXTheme.line, lineWidth: 1)
        )
    }

    private func step(reverse: Bool) {
        LogXMotion.perform(LogXMotion.snappy) {
            index = JSONFind.nextIndex(current: index, count: matchCount, reverse: reverse)
        }
    }

    private func stepButton(icon: String, help: String, label: String, reverse: Bool) -> some View {
        Button {
            step(reverse: reverse)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(LogXTheme.muted)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 5).fill(LogXTheme.well))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(LogXTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
        .disabled(matchCount == 0)
    }
}
