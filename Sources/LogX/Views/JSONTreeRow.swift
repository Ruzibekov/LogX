import AppKit
import SwiftUI
import LogXCore

/// Bitta qator; hover holati shu yerda — butun daraxt qayta hisoblanmaydi.
struct JSONTreeRow<Menu: View>: View {
    let node: JSONNode
    let isCollapsed: Bool
    let matched: Bool
    let active: Bool
    let query: String
    let indicatorToken: Int
    let onToggle: (Bool) -> Void
    @ViewBuilder let menu: () -> Menu
    @State private var hovered = false
    @State private var indicating = false

    var body: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(node.depth) * 14 + 6, height: 1)
            if node.kind.isContainer, node.childCount > 0 {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(LogXTheme.muted)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 12)
            } else {
                Color.clear.frame(width: 12, height: 1)
            }
            if node.depth > 0 {
                Text(TreeFindHighlight.text(node.key, query: query, active: active))
                    .font(LogXType.mono(11.5, .medium))
                    .foregroundStyle(node.key.hasPrefix("[") ? LogXTheme.muted : JSONHighlighter.spanColor(.key))
                    .lineLimit(1)
                    .overlay(alignment: .leading) { findIndicator(node.key, font: LogXType.mono(11.5, .medium)) }
                    .layoutPriority(1)
                Text(":")
                    .font(LogXType.mono(LogXType.body))
                    .foregroundStyle(JSONHighlighter.spanColor(.punct))
            }
            if node.kind.isContainer {
                containerValue
            } else {
                Text(TreeFindHighlight.text(node.displayValue, query: query, active: active))
                    .font(LogXType.mono(LogXType.body))
                    .foregroundStyle(scalarColor(node.kind))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .overlay(alignment: .leading) { findIndicator(node.displayValue, font: LogXType.mono(LogXType.body)) }
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
        }
        .padding(.vertical, 2)
        .padding(.trailing, 12)
        .frame(minHeight: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Rectangle().fill(
                active ? LogXTheme.warn.opacity(0.28)
                    : matched ? LogXTheme.accent.opacity(0.16)
                    : hovered ? LogXTheme.panel2 : Color.clear
            )
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onToggle(NSEvent.modifierFlags.contains(.option)) }
        .contextMenu { menu() }
        .help(node.kind.isContainer ? node.id : "\(node.id)\n\(node.scalar ?? "")")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(node.kind.isContainer ? .isButton : [])
        .task(id: indicatorToken) {
            await runFindIndicator()
        }
    }

    @ViewBuilder
    private func findIndicator(_ value: String, font: Font) -> some View {
        if indicating, let text = TreeFindHighlight.indicator(value, query: query) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .truncationMode(.tail)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity.combined(with: .scale(scale: 1.12, anchor: .leading)))
        }
    }

    private func runFindIndicator() async {
        guard indicatorToken > 0, !LogXMotion.reduceMotion else {
            indicating = false
            return
        }
        indicating = false
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.15)) { indicating = true }
        try? await Task.sleep(for: .milliseconds(900))
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.3)) { indicating = false }
    }

    private var containerValue: some View {
        HStack(spacing: 5) {
            Text(node.childCount == 0 ? node.openBracket + node.closeBracket
                 : isCollapsed ? node.openBracket + "…" + node.closeBracket
                 : node.openBracket)
                .font(LogXType.mono(LogXType.body))
                .foregroundStyle(JSONHighlighter.spanColor(.punct))
            if node.childCount > 0 {
                Text("\(node.childCount) ta")
                    .font(LogXType.mono(9.5, .semibold))
                    .foregroundStyle(LogXTheme.muted2)
                    .fixedSize()
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(LogXTheme.well))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
            }
        }
    }

    private func scalarColor(_ kind: JSONNode.Kind) -> Color {
        switch kind {
        case .string: return JSONHighlighter.spanColor(.string)
        case .number: return JSONHighlighter.spanColor(.number)
        case .bool, .null: return JSONHighlighter.spanColor(.boolNull)
        case .object, .array: return JSONHighlighter.spanColor(.punct)
        }
    }

    private var accessibilityText: String {
        let name = node.depth == 0 ? "ildiz" : node.key
        if node.kind.isContainer {
            return "\(name), \(node.kind == .array ? "massiv" : "obyekt"), \(node.childCount) ta, \(isCollapsed ? "yig'iq" : "yoyiq")"
        }
        return "\(name): \(node.displayValue)"
    }
}
