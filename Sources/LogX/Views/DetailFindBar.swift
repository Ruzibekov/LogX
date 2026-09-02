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
                .foregroundStyle(LogXTheme.muted2)
            TextField("Tana ichida topish (⌥⌘F)", text: $query)
                .accessibilityLabel("JSON ichida topish")
                .focused($focused)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
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
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(matchCount == 0 ? LogXTheme.muted2 : LogXTheme.accentLight)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(matchCount == 0 ? LogXTheme.well : LogXTheme.chipOn))
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: label)
            stepButton(icon: "chevron.up", help: "Oldingi (⇧⌘G)", label: "Oldingi topilma", reverse: true)
                .keyboardShortcut("g", modifiers: [.command, .shift])
            stepButton(icon: "chevron.down", help: "Keyingi (⌘G)", label: "Keyingi topilma", reverse: false)
                .keyboardShortcut("g", modifiers: .command)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(LogXTheme.well)
    }

    private func step(reverse: Bool) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
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
