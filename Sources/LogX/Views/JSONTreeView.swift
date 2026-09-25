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
    @State private var finder = TreeFinder()
    @State private var revealToken = 0

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
        let matches = finder.matches(in: tree, query: query)
        let matchSet = Set(matches)
        let active = activeID(in: matches)
        let rows = tree.rows(collapsed: collapsed)
        let token = revealToken
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
                                query: matchSet.contains(node.id) ? query : "",
                                indicatorToken: node.id == active ? token : 0,
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
            LogXMotion.perform(LogXMotion.expand) {
                proxy.scrollTo(id, anchor: .center)
            }
            revealToken &+= 1
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
                    .font(LogXType.ui(11, .medium))
            }
            .foregroundStyle(LogXTheme.muted)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func toggle(_ node: JSONNode, deep: Bool) {
        guard node.kind.isContainer, node.childCount > 0 else { return }
        let ids = deep ? tree.subtreeContainerIDs(of: node.id) : [node.id]
        LogXMotion.perform(LogXMotion.hover) {
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
