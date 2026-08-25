import SwiftUI
import LogXCore

struct DetailFindBar: View {
    @Binding var query: String
    @Binding var index: Int
    var display: String

    private var matches: [Range<String.Index>] {
        JSONFind.matches(display, query: query)
    }

    private var label: String {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return "0" }
        if matches.isEmpty { return "0" }
        let idx = min(max(index, 0), matches.count - 1)
        return "\(idx + 1)/\(matches.count)"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LogXTheme.muted2)
            TextField("Topish", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LogXTheme.text)
                .onChange(of: query) { _, _ in
                    index = 0
                }
            Text(label)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(matches.isEmpty ? LogXTheme.muted2 : LogXTheme.accentLight)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(matches.isEmpty ? LogXTheme.well : LogXTheme.accent.opacity(0.16)))
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: label)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    index = JSONFind.nextIndex(current: index, count: matches.count, reverse: true)
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LogXTheme.muted)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(LogXTheme.well))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(LogXTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .help("Oldingi (⇧⌘G)")
            .disabled(matches.isEmpty)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    index = JSONFind.nextIndex(current: index, count: matches.count, reverse: false)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LogXTheme.muted)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(LogXTheme.well))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(LogXTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("g", modifiers: .command)
            .help("Keyingi (⌘G)")
            .disabled(matches.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(LogXTheme.well)
    }
}
