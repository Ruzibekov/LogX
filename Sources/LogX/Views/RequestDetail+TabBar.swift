import SwiftUI
import LogXCore

extension RequestDetail {
    var zoom: Double { fontSize / 11.5 }

    func stepZoom(multiplier: Double) {
        let next = max(8.0, min(24.0, fontSize * multiplier))
        fontSize = (next * 10).rounded() / 10
    }

    func resetZoom() { fontSize = 11.5 }

    @ViewBuilder
    func tabBar(log: NetworkLog, treeAvailable: Bool?) -> some View {
        HStack(spacing: 22) {
            tabButtons(log: log)
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 42)
        .padding(.horizontal, 22)
        .background(LogXTheme.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(LogXTheme.line).frame(height: 1) }
    }

    @ViewBuilder
    func subToolbar(log: NetworkLog, rendered: RenderedBody?, treeAvailable: Bool?) -> some View {
        HStack(spacing: 8) {
            viewModeSegment(treeAvailable: treeAvailable)
            DetailFindBar(query: $findQuery, index: $findIndex, matchCount: rendered?.tree != nil ? treeMatchCount : FindCount.display(rendered: rendered, snapshot: findCount, query: findQuery))
                .frame(minWidth: 120, maxWidth: 240)
                .layoutPriority(1)
            Spacer(minLength: 8)
            ViewThatFits(in: .horizontal) {
                trailingTools(meta: bodyMeta(log: log, rendered: rendered), zoom: true, log: log)
                trailingTools(meta: bodyMeta(log: log, rendered: rendered, includeType: false), zoom: true, log: log)
                trailingTools(meta: bodyMeta(log: log, rendered: rendered, includeType: false, includeLines: false), zoom: true, log: log)
                trailingTools(meta: nil, zoom: true, log: log)
                trailingTools(meta: nil, zoom: false, log: log)
                copyBodyButton(log: log, labelled: false)
            }
            .help(bodyMeta(log: log, rendered: rendered))
        }
        .padding(.horizontal, 22)
        .frame(minHeight: 40)
        .background(LogXTheme.well)
        .overlay(alignment: .bottom) { Rectangle().fill(LogXTheme.divider).frame(height: 1) }
    }

    func trailingTools(meta: String?, zoom: Bool, log: NetworkLog) -> some View {
        HStack(spacing: 8) {
            if let meta { metaText(meta) }
            if zoom, tab == .request || tab == .response { zoomControls }
            copyBodyButton(log: log, labelled: true)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    func metaText(_ text: String) -> some View {
        Text(text)
            .font(LogXType.mono(LogXType.caption))
            .foregroundStyle(LogXTheme.muted)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    func bodyMeta(log: NetworkLog, rendered: RenderedBody?, includeType: Bool = true, includeLines: Bool = true) -> String {
        var parts: [String] = []
        if let rendered {
            parts.append(ByteSize.label(rendered.text.utf8.count))
            if includeLines, rendered.lineCount > 1 { parts.append("\(rendered.lineCount) qator") }
        }
        let headers = (tab == .request) ? log.requestHeaders : log.responseHeaders
        if includeType, let type = headers.first(where: { $0.key.lowercased() == "content-type" })?.value {
            parts.append(type.split(separator: ";").first.map(String.init) ?? type)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    func viewModeSegment(treeAvailable: Bool?) -> some View {
        switch tab {
        case .request, .response:
            HStack(spacing: 0) {
                segmentButton("Daraxt", active: treeBody, help: treeAvailable == false && treeBody
                    ? "Tana JSON emas yoki \(JSONTree.nodeLimit) tugundan katta — matn ko'rsatilmoqda"
                    : "JSON'ni yig'iladigan daraxt sifatida ko'rsatish (⌥-bosish butun shoxni yig'adi)") {
                    treeBody = true
                }
                segmentButton("Matn", active: !treeBody && prettyBody, help: "Formatlangan JSON matni") {
                    treeBody = false
                    prettyBody = true
                }
                segmentButton("Xom", active: !treeBody && !prettyBody, help: "Serverdan kelgan asl matn") {
                    treeBody = false
                    prettyBody = false
                }
            }
            .modifier(SegmentFrame())
            wrapButton
        case .headers:
            HStack(spacing: 0) {
                segmentButton("Jadval", active: headersTableView, help: "Strukturali jadval ko'rinishi") {
                    headersTableView = true
                }
                segmentButton("Matn", active: !headersTableView, help: "Matnli ko'rinish") {
                    headersTableView = false
                }
            }
            .modifier(SegmentFrame())
            wrapButton
        case .params:
            EmptyView()
        }
    }

    var wrapButton: some View {
        Button {
            LogXMotion.perform(LogXMotion.snappy) { toggleWrapBody() }
        } label: {
            Image(systemName: isWrapBody ? "text.alignleft" : "arrow.left.and.right")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isWrapBody ? LogXTheme.accent : LogXTheme.muted)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                        .fill(isWrapBody ? LogXTheme.chipOn : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                        .stroke(isWrapBody ? LogXTheme.chipOnEdge : LogXTheme.line, lineWidth: 1)
                )
        }
        .buttonStyle(LogXPressStyle())
        .help(isWrapBody ? "Uzun qatorni gorizontal aylanma qilish" : "Matnni oynaga sig'dirish")
        .accessibilityLabel("Qator o'rash")
        .accessibilityValue(isWrapBody ? "yoqilgan" : "o'chirilgan")
    }

    func copyBodyButton(log: NetworkLog, labelled: Bool = true) -> some View {
        Button {
            copy(JSONFormat.body(for: log, tab: tab, redact: store.redactEnabled, pretty: prettyBody))
        } label: {
            HStack(spacing: 5) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                if labelled {
                    Text(copied ? "Nusxalandi" : "Nusxa")
                        .font(LogXType.ui(LogXType.meta, .medium))
                }
            }
            .foregroundStyle(copied ? LogXTheme.ok : LogXTheme.text2)
        }
        .buttonStyle(LogXButtonStyle(kind: .outline, height: 28, horizontalPadding: 10))
        .keyboardShortcut("c", modifiers: [.option, .command])
        .help("Tanani nusxalash (⌥⌘C)")
        .accessibilityLabel("Tanani nusxalash")
    }

    func segmentButton(_ title: String, active: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button {
            LogXMotion.perform(LogXMotion.snappy) { action() }
        } label: {
            Text(title)
                .font(LogXType.ui(LogXType.meta, active ? .semibold : .medium))
                .foregroundStyle(active ? LogXTheme.text : LogXTheme.text2)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(active ? LogXTheme.panel2 : Color.clear)
        }
        .buttonStyle(LogXPressStyle())
        .help(help)
    }

    @ViewBuilder
    func tabButtons(log: NetworkLog) -> some View {
        ForEach(DetailTab.allCases, id: \.self) { item in
            Button {
                LogXMotion.perform(LogXMotion.snappy) {
                    store.detailTab = item
                }
            } label: {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(LogXType.ui(LogXType.body, tab == item ? .semibold : .medium))
                        .lineLimit(1)
                    Text("⌘\(String(tabShortcut(item).character))")
                        .font(LogXType.mono(9.5))
                        .foregroundStyle(LogXTheme.muted)
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
                .frame(maxHeight: .infinity)
                .foregroundStyle(tab == item ? LogXTheme.text : LogXTheme.muted)
                .contentShape(Rectangle())
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

    func tabShortcut(_ item: DetailTab) -> KeyEquivalent {
        switch item {
        case .response: return "1"
        case .request: return "2"
        case .headers: return "3"
        case .params: return "4"
        }
    }
}

struct SegmentFrame: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
        return content
            .clipShape(shape)
            .overlay(shape.stroke(LogXTheme.line, lineWidth: 1))
    }
}
