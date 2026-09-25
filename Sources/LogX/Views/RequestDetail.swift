import AppKit
import SwiftUI
import LogXCore

struct RequestDetail: View {
    @EnvironmentObject var store: LogStore
    @State var copied = false
    @State var findQuery = ""
    @State var findIndex = 0
    /// Default: uzun qator o'ralmaydi — gorizontal aylanma; «O'rash» ixtiyoriy.
    @AppStorage("logx.wrapBody") private var wrapBody = false
    @AppStorage("logx.prettyBody") var prettyBody = true
    /// JSON tanani yig'iladigan daraxt sifatida ko'rsatish (faqat so'rov/javob tabida).
    @AppStorage("logx.treeBody") var treeBody = false
    @AppStorage("logx.detailFontSize") var fontSize: Double = 11.5
    @AppStorage("logx.headersTableView") var headersTableView = true
    @State var treeMatchCount = 0
    @StateObject var shareHost = SharePickerHost()
    @State private var bodyCache: RenderedBody?

    var isWrapBody: Bool { wrapBody }
    func toggleWrapBody() { wrapBody.toggle() }

    func showRawAndWrap(treeAvailable: Bool?) -> Bool {
        if treeAvailable != true {
            return true
        }
        return false
    }

    var tab: DetailTab { store.detailTab }

    var body: some View {
        Group {
            if let log = store.selectedLog {
                detail(log)
            } else {
                noSelectionPlaceholder
            }
        }
        .background(LogXTheme.bg)
    }

    /// Daraxt rejimida topish so'rovi kalitga kirmaydi — har harfda daraxt qayta
    /// qurilmaydi, yig'ilgan/yoyilgan holat va scroll saqlanadi.
    private func renderKey(_ log: NetworkLog) -> RenderedBody.Key {
        let tree = treeBody && (tab == .request || tab == .response)
        return RenderedBody.Key(
            logKey: log.key,
            tab: tab,
            redact: store.redactEnabled,
            pretty: prettyBody,
            query: tree ? "" : findQuery,
            index: tree ? 0 : findIndex,
            tree: tree,
            fontSize: CGFloat(fontSize)
        )
    }

    private func detail(_ log: NetworkLog) -> some View {
        let key = renderKey(log)
        let rendered = (bodyCache?.key == key) ? bodyCache : nil
        let params = store.redactEnabled ? Redactor.maskParams(log.queryParams) : log.queryParams
        return VStack(alignment: .leading, spacing: 0) {
            DetailHeader(
                log: log,
                tab: tab,
                onCopyBody: { copy(JSONFormat.body(for: log, tab: tab, redact: store.redactEnabled, pretty: prettyBody)) },
                onShare: { share(log) }
            )
            if store.selectedIsHidden {
                hiddenBanner
            }
            Divider().overlay(LogXTheme.divider)
            tabBar(log: log, treeAvailable: rendered.map { $0.tree != nil })
            subToolbar(log: log, rendered: rendered, treeAvailable: rendered.map { $0.tree != nil })
            Group {
                if tab == .headers && headersTableView && findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView {
                        headersTable(log)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(bodyWell)
                            .padding(10)
                    }
                } else if tab == .params && !params.isEmpty && findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView {
                        paramsTable(params)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(bodyWell)
                            .padding(10)
                    }
                } else if let rendered, let tree = rendered.tree {
                    JSONTreeView(tree: tree, query: findQuery, activeIndex: findIndex) { treeMatchCount = $0 }
                        .id(tree.identity)
                        .background(codeWell)
                } else if let rendered {
                    VStack(spacing: 0) {
                        if let notice = rendered.truncationNotice {
                            truncationStrip(notice)
                        }
                        BodyTextView(text: rendered.attributed, wrap: wrapBody, activeRange: rendered.activeRange, fontSize: CGFloat(fontSize))
                    }
                    .background(codeWell)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            SharePickerAnchor(host: shareHost)
                .frame(width: 1, height: 1)
        }
        .task(id: key) {
            await render(log: log, key: key)
        }
        .onChange(of: store.selectedKey) { _, _ in
            findIndex = 0
        }
        .onChange(of: store.detailTab) { _, _ in
            findIndex = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: LogXNotice.zoomIn)) { _ in
            stepZoom(multiplier: 1.15)
        }
        .onReceive(NotificationCenter.default.publisher(for: LogXNotice.zoomOut)) { _ in
            stepZoom(multiplier: 0.85)
        }
        .onReceive(NotificationCenter.default.publisher(for: LogXNotice.zoomReset)) { _ in
            resetZoom()
        }
    }

    /// Pretty-print, topish va rang berish asosiy oqimdan tashqarida; natija
    /// kalit bo'yicha keshlanadi — jonli rejimda (20 Hz publish) qayta hisoblanmaydi.
    private func render(log: NetworkLog, key: RenderedBody.Key) async {
        if bodyCache?.key == key { return }
        let next = await Task.detached(priority: .userInitiated) {
            RenderedBody.make(log: log, key: key)
        }.value
        guard !Task.isCancelled else { return }
        bodyCache = next
    }

    private func actionBar(_ log: NetworkLog) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                copyPill(log: log)
                curlPill(log: log)
                replayPill(log: log)
                editReplayPill(log: log)
                sharePill(log: log)
                Spacer(minLength: 0)
                redactToggle
            }
            WrapLayout(spacing: 10, lineSpacing: 6) {
                copyPill(log: log)
                curlPill(log: log)
                replayPill(log: log)
                editReplayPill(log: log)
                sharePill(log: log)
                redactToggle
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(LogXTheme.panel)
        .overlay(Divider().overlay(LogXTheme.divider), alignment: .top)
    }

    func replayPill(log: NetworkLog) -> some View {
        ActionPillButton(
            title: store.selectedIsReplaying ? "Yuborilmoqda…" : "Qayta yuborish",
            icon: "arrow.clockwise",
            help: store.replayBlocker(log) ?? "So'rovni Mac'dan qayta yuborish — javob ro'yxatga REPLAY bo'lib tushadi (⌘⏎)"
        ) {
            store.replay(log)
        }
        .disabled(!store.canReplay(log))
        .keyboardShortcut(.return, modifiers: .command)
    }

    private var redactToggle: some View {
        Toggle(isOn: Binding(
            get: { store.redactEnabled },
            set: { store.redactEnabled = $0 }
        )) {
            HStack(spacing: 4) {
                Image(systemName: store.redactEnabled ? "eye.slash" : "eye")
                    .font(.system(size: 10, weight: .semibold))
                Text("Tokenlarni yashir")
            }
                .font(.system(size: 10.5, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(store.redactEnabled ? LogXTheme.accentLight : LogXTheme.muted)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(store.redactEnabled ? LogXTheme.chipOn : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    store.redactEnabled ? LogXTheme.chipOnEdge : LogXTheme.line, lineWidth: 1
                )
        )
        .fixedSize(horizontal: true, vertical: false)
        .help("Yoqilsa ekran, ro'yxat, cURL, eksport va ulashishda token yashiriladi (⌘⇧T)")
    }
}
