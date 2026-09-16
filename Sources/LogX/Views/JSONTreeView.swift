import SwiftUI
import LogXCore

/// Tana JSON daraxti: yig'iladigan konteynerlar, yo'l/qiymat nusxasi, topish
/// bilan integratsiya (topilma yoyiladi va ko'rinadigan joyga suriladi).
/// Faqat vertikal aylanma — ikki o'qli ScrollView LazyVStack kengligini yo'qotadi;
/// uzun qiymat bir qatorda kesiladi, to'lig'i tooltip va nusxada.
struct JSONTreeView: View {
    let tree: JSONTree
    var query: String
    var activeIndex: Int
    var onMatchCount: (Int) -> Void

    @EnvironmentObject private var store: LogStore
    @State private var collapsed: Set<String>

    init(tree: JSONTree, query: String, activeIndex: Int, onMatchCount: @escaping (Int) -> Void) {
        self.tree = tree
        self.query = query
        self.activeIndex = activeIndex
        self.onMatchCount = onMatchCount
        _collapsed = State(initialValue: tree.defaultCollapsed())
    }

    private var allCollapsed: Set<String> {
        tree.containerIDs.subtracting(tree.nodes.first.map { [$0.id] } ?? [])
    }

    private func activeID(in matches: [String]) -> String? {
        guard !matches.isEmpty else { return nil }
        return matches[min(max(activeIndex, 0), matches.count - 1)]
    }

    var body: some View {
        let matches = tree.matches(query: query)
        let matchSet = Set(matches)
        let active = activeID(in: matches)
        let rows = tree.rows(collapsed: collapsed)
        VStack(spacing: 0) {
            toolbar(rows: rows.count)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { node in
                            JSONTreeRow(
                                node: node,
                                isCollapsed: node.kind.isContainer && collapsed.contains(node.id),
                                matched: matchSet.contains(node.id),
                                active: node.id == active,
                                onToggle: { deep in toggle(node, deep: deep) },
                                menu: { rowMenu(node) }
                            )
                            .id(node.id)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: active) { _, id in
                    reveal(id, proxy: proxy)
                }
                .onAppear {
                    onMatchCount(matches.count)
                    reveal(active, proxy: proxy)
                }
                .onChange(of: matches.count) { _, count in
                    onMatchCount(count)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("JSON daraxti")
    }

    private func reveal(_ id: String?, proxy: ScrollViewProxy) {
        guard let id else { return }
        let ancestors = tree.ancestorIDs(of: id)
        if ancestors.contains(where: { collapsed.contains($0) }) {
            collapsed.subtract(ancestors)
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    private func toolbar(rows: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(tree.count) tugun · \(rows) qator")
                .font(LogXType.mono(LogXType.caption))
                .foregroundStyle(LogXTheme.muted2)
            Spacer(minLength: 0)
            treeButton("Hammasini yoyish", icon: "arrow.up.left.and.arrow.down.right") {
                collapsed = []
            }
            .disabled(collapsed.isEmpty)
            treeButton("Hammasini yig'ish", icon: "arrow.down.right.and.arrow.up.left") {
                collapsed = allCollapsed
            }
            .disabled(collapsed == allCollapsed)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(LogXTheme.panel2)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    private func treeButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(LogXTheme.muted)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func toggle(_ node: JSONNode, deep: Bool) {
        guard node.kind.isContainer, node.childCount > 0 else { return }
        let ids = deep ? tree.subtreeContainerIDs(of: node.id) : [node.id]
        withAnimation(.easeOut(duration: 0.12)) {
            if collapsed.contains(node.id) {
                collapsed.subtract(ids)
            } else {
                collapsed.formUnion(ids)
            }
        }
    }

    @ViewBuilder
    private func rowMenu(_ node: JSONNode) -> some View {
        Button("Qiymatni nusxalash") {
            store.copy(tree.valueText(id: node.id) ?? "", what: node.depth == 0 ? "JSON" : node.key)
        }
        Button("Yo'lni nusxalash") { store.copy(node.id, what: "yo'l") }
        if node.depth > 0, !node.key.hasPrefix("[") {
            Button("Kalitni nusxalash") { store.copy(node.key, what: "kalit") }
        }
        if !node.kind.isContainer, let value = tree.valueText(id: node.id), !value.isEmpty, value != "null" {
            Divider()
            Button("Ro'yxatda «\(value.count > 24 ? String(value.prefix(24)) + "…" : value)» ni qidirish") {
                store.applyQuery(value)
            }
        }
        if node.kind.isContainer, node.childCount > 0 {
            Divider()
            Button(collapsed.contains(node.id) ? "Shoxni yoyish" : "Shoxni yig'ish") { toggle(node, deep: true) }
        }
    }
}

/// Bitta qator; hover holati shu yerda — butun daraxt qayta hisoblanmaydi.
private struct JSONTreeRow<Menu: View>: View {
    let node: JSONNode
    let isCollapsed: Bool
    let matched: Bool
    let active: Bool
    let onToggle: (Bool) -> Void
    @ViewBuilder let menu: () -> Menu
    @State private var hovered = false

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
                Text(node.key)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(node.key.hasPrefix("[") ? LogXTheme.muted : JSONHighlighter.spanColor(.key))
                    .lineLimit(1)
                    .layoutPriority(1)
                Text(":")
                    .font(LogXType.mono(LogXType.body))
                    .foregroundStyle(JSONHighlighter.spanColor(.punct))
            }
            if node.kind.isContainer {
                containerValue
            } else {
                Text(node.displayValue)
                    .font(LogXType.mono(LogXType.body))
                    .foregroundStyle(scalarColor(node.kind))
                    .lineLimit(1)
                    .truncationMode(.tail)
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
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
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
