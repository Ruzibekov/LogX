import SwiftUI
import LogXCore

extension RequestDetail {
    var zoom: Double { fontSize / 11.5 }

    func stepZoom(multiplier: Double) {
        let next = max(8.0, min(24.0, fontSize * multiplier))
        fontSize = (next * 10).rounded() / 10
    }

    func resetZoom() { fontSize = 11.5 }

    /// Keng panelda tablar chapda, tugmalar o'ngda — eskirgan ko'rinish.
    /// Panelda joy qolmaganda ViewThatFits oqim variantiga o'tadi: tablar va
    /// tugmalar qatorma-qator oqadi, matn o'rtadan yorilmaydi.
    @ViewBuilder
    func tabBar(log: NetworkLog, treeAvailable: Bool?) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                tabButtons(log: log)
                Spacer(minLength: 8)
                tabToggles(treeAvailable: treeAvailable)
            }
            WrapLayout(spacing: 12, lineSpacing: 6) {
                tabButtons(log: log)
                tabToggles(treeAvailable: treeAvailable)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        .background(LogXTheme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(LogXTheme.line).frame(height: 1) }
    }

    @ViewBuilder
    func tabButtons(log: NetworkLog) -> some View {
        ForEach(DetailTab.allCases, id: \.self) { item in
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    store.detailTab = item
                }
            } label: {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(LogXType.ui(LogXType.body, tab == item ? .semibold : .medium))
                        .lineLimit(1)
                    if item == .params && !log.queryParams.isEmpty {
                        Text("\(log.queryParams.count)")
                            .font(LogXType.mono(LogXType.caption, .bold))
                            .foregroundStyle(tab == item ? LogXTheme.accent : LogXTheme.muted2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                (tab == item ? LogXTheme.chipOn : LogXTheme.panel2),
                                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                            )
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 4)
                .padding(.top, 5)
                .padding(.bottom, 6)
                .foregroundStyle(tab == item ? LogXTheme.text : LogXTheme.muted)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(tab == item ? LogXTheme.accent : Color.clear)
                        .frame(height: 2)
                }
            }
            .buttonStyle(.plain)
            .help("\(item.title) (⌘\(String(tabShortcut(item).character)))")
            .keyboardShortcut(tabShortcut(item), modifiers: .command)
        }
    }

    @ViewBuilder
    func tabToggles(treeAvailable: Bool?) -> some View {
        if tab == .headers {
            togglePill(
                on: headersTableView,
                icon: headersTableView ? "tablecells" : "doc.plaintext",
                title: headersTableView ? "Jadval" : "Matn",
                help: headersTableView ? "Matnli ko'rinishga o'tish" : "Strukturali jadval ko'rinishiga o'tish",
                label: "Jadval ko'rinishi"
            ) {
                headersTableView.toggle()
            }
        }
        if tab == .request || tab == .response {
            togglePill(
                on: treeBody,
                icon: "list.bullet.indent",
                title: "Daraxt",
                help: treeBody
                    ? (treeAvailable == false ? "Tana JSON emas yoki \(JSONTree.nodeLimit) tugundan katta — matn ko'rsatilmoqda; bosilsa daraxt o'chadi" : "Matn ko'rinishiga qaytish")
                    : "JSON'ni yig'iladigan daraxt sifatida ko'rsatish (⌥-bosish butun shoxni yig'adi)",
                label: "JSON daraxti"
            ) {
                treeBody.toggle()
            }
        }
        if showRawAndWrap(treeAvailable: treeAvailable) {
            if tab == .request || tab == .response {
                togglePill(
                    on: !prettyBody,
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "Raw",
                    help: prettyBody ? "Serverdan kelgan asl matnni ko'rsatish" : "Formatlangan JSON ko'rsatish",
                    label: "Asl matn"
                ) {
                    prettyBody.toggle()
                }
            }
            togglePill(
                on: isWrapBody,
                icon: isWrapBody ? "text.alignleft" : "arrow.left.and.right",
                title: "O'rash",
                help: isWrapBody ? "Uzun qatorni gorizontal aylanma qilish" : "Matnni oynaga sig'dirish",
                label: "Qator o'rash"
            ) {
                toggleWrapBody()
            }
        }
        if tab == .request || tab == .response {
            zoomControls
        }
    }

    var zoomControls: some View {
        HStack(spacing: 3) {
            Button {
                stepZoom(multiplier: 0.85)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(LogXTheme.muted)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 4).fill(LogXTheme.well))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(LogXTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Kichiklashtirish (⌘- yoki trackpad chimchilash)")
            .accessibilityLabel("Kichiklashtirish")

            Button {
                resetZoom()
            } label: {
                Text("\(Int(round(zoom * 100)))%")
                    .font(LogXType.mono(LogXType.caption, .semibold))
                    .foregroundStyle(abs(zoom - 1.0) > 0.02 ? LogXTheme.accentLight : LogXTheme.muted2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(abs(zoom - 1.0) > 0.02 ? LogXTheme.chipOn : LogXTheme.well)
                    )
            }
            .buttonStyle(.plain)
            .help("Masshtabni 100% ga qaytarish (⌘0)")
            .accessibilityLabel("Masshtab 100%")

            Button {
                stepZoom(multiplier: 1.15)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(LogXTheme.muted)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(LogXTheme.well))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Kattalashtirish (⌘+ yoki trackpad chimchilash)")
            .accessibilityLabel("Kattalashtirish")
        }
        .padding(.leading, 2)
    }

    func togglePill(on: Bool, icon: String, title: String, help: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(LogXType.ui(LogXType.meta, .semibold))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(on ? LogXTheme.text : LogXTheme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(on ? LogXTheme.chipOn : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(on ? LogXTheme.chipOnEdge : LogXTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "yoqilgan" : "o'chirilgan")
    }

    func tabShortcut(_ item: DetailTab) -> KeyEquivalent {
        switch item {
        case .response: return "1"
        case .request: return "2"
        case .headers: return "3"
        case .params: return "4"
        }
    }
}
