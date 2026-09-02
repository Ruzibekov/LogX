import AppKit
import SwiftUI
import LogXCore

struct RequestDetail: View {
    @EnvironmentObject private var store: LogStore
    @State private var copied = false
    @State private var findQuery = ""
    @State private var findIndex = 0
    /// Default: uzun qator o'ralmaydi — gorizontal aylanma; «O'rash» ixtiyoriy.
    @AppStorage("logx.wrapBody") private var wrapBody = false
    @AppStorage("logx.prettyBody") private var prettyBody = true
    @StateObject private var shareHost = SharePickerHost()
    @State private var bodyCache: RenderedBody?

    private var tab: DetailTab { store.detailTab }

    var body: some View {
        Group {
            if let log = store.selectedLog {
                detail(log)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 32))
                        .foregroundStyle(LogXTheme.muted2)
                    Text("So'rov tanlang")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LogXTheme.muted)
                    Text("↑↓ bilan yuring, ⌘F qidiradi")
                        .font(.system(size: 11))
                        .foregroundStyle(LogXTheme.muted2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(LogXTheme.panel)
    }

    private func renderKey(_ log: NetworkLog) -> RenderedBody.Key {
        RenderedBody.Key(
            logKey: log.key,
            tab: tab,
            redact: store.redactEnabled,
            pretty: prettyBody,
            query: findQuery,
            index: findIndex
        )
    }

    private func detail(_ log: NetworkLog) -> some View {
        let key = renderKey(log)
        let rendered = (bodyCache?.key == key) ? bodyCache : nil
        let params = store.redactEnabled ? Redactor.maskParams(log.queryParams) : log.queryParams
        return VStack(alignment: .leading, spacing: 0) {
            DetailHeader(log: log, tab: tab)
            if store.selectedIsHidden {
                hiddenBanner
            }
            Divider().overlay(LogXTheme.divider)
            tabBar(log: log)
            Divider().overlay(LogXTheme.divider)
            DetailFindBar(query: $findQuery, index: $findIndex, matchCount: rendered?.matchCount ?? 0)
            Divider().overlay(LogXTheme.divider)
            Group {
                if tab == .params && !params.isEmpty && findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView {
                        paramsTable(params)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(bodyWell)
                            .padding(10)
                    }
                } else if let rendered {
                    VStack(spacing: 0) {
                        if let notice = rendered.truncationNotice {
                            truncationStrip(notice)
                        }
                        BodyTextView(text: rendered.attributed, wrap: wrapBody, activeRange: rendered.activeRange)
                    }
                    .background(bodyWell)
                    .padding(10)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            actionBar(log)
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
    }

    private var bodyWell: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(LogXTheme.well)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(LogXTheme.line, lineWidth: 1)
            )
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

    private var hiddenBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 10.5, weight: .semibold))
            Text("Bu so'rov joriy filtr bilan ro'yxatda ko'rinmaydi")
                .font(.system(size: 11, weight: .medium))
            Spacer(minLength: 4)
            Button("Filtrlarni tozalash") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    store.clearFilters()
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(LogXTheme.accentLight)
        }
        .foregroundStyle(LogXTheme.warn)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LogXTheme.warn.opacity(0.1))
    }

    private func truncationStrip(_ notice: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "scissors")
                .font(.system(size: 10, weight: .semibold))
            Text(notice)
                .font(.system(size: 10.5, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(LogXTheme.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(LogXTheme.panel2)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
    }

    private func paramsTable(_ params: [(key: String, value: String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(params.enumerated()), id: \.offset) { idx, pair in
                ParamRowView(key: pair.key, value: pair.value, isEven: idx % 2 == 0)
                if idx < params.count - 1 {
                    Divider().overlay(LogXTheme.divider)
                }
            }
        }
    }

    private func tabBar(log: NetworkLog) -> some View {
        HStack(spacing: 5) {
            ForEach(DetailTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        store.detailTab = item
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(item.title)
                            .font(.system(size: 11.5, weight: tab == item ? .semibold : .medium))
                        if item == .params && !log.queryParams.isEmpty {
                            Text("\(log.queryParams.count)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(tab == item ? LogXTheme.accentLight : LogXTheme.muted2)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(tab == item ? LogXTheme.chipOn : LogXTheme.well)
                                )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Capsule().fill(tab == item ? LogXTheme.chipOn : Color.clear))
                    .overlay(
                        Capsule().stroke(tab == item ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(tab == item ? LogXTheme.text : LogXTheme.muted)
                }
                .buttonStyle(.plain)
                .help("\(item.title) (⌘\(tabShortcut(item).character))")
                .keyboardShortcut(tabShortcut(item), modifiers: .command)
            }
            Spacer()
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
                on: wrapBody,
                icon: wrapBody ? "text.alignleft" : "arrow.left.and.right",
                title: "O'rash",
                help: wrapBody ? "Uzun qatorni gorizontal aylanma qilish" : "Matnni oynaga sig'dirish",
                label: "Qator o'rash"
            ) {
                wrapBody.toggle()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(LogXTheme.well)
    }

    private func togglePill(on: Bool, icon: String, title: String, help: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(on ? LogXTheme.text : LogXTheme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(on ? LogXTheme.chipOn : Color.clear))
            .overlay(Capsule().stroke(on ? LogXTheme.chipOnEdge : LogXTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "yoqilgan" : "o'chirilgan")
    }

    private func tabShortcut(_ item: DetailTab) -> KeyEquivalent {
        switch item {
        case .response: return "1"
        case .request: return "2"
        case .headers: return "3"
        case .params: return "4"
        }
    }

    private func actionBar(_ log: NetworkLog) -> some View {
        HStack(spacing: 12) {
            ActionPillButton(
                title: copied ? "Nusxalandi" : "Nusxa",
                shortcut: [.symbol("option"), .symbol("command"), .letter("C")],
                isPrimary: true,
                help: "Tanani nusxalash (⌥⌘C)"
            ) {
                copy(JSONFormat.body(for: log, tab: tab, redact: store.redactEnabled, pretty: prettyBody))
            }

            ActionPillButton(
                title: "cURL",
                shortcut: [.symbol("command"), .symbol("shift"), .letter("C")],
                help: "cURL buyrug'ini nusxalash (⌘⇧C)"
            ) {
                store.copy(CurlBuilder.command(for: log, redact: store.redactEnabled), what: "cURL")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            ActionPillButton(title: "Ulashish", icon: "square.and.arrow.up", help: "Rasm sifatida ulashish") {
                share(log)
            }

            Spacer(minLength: 0)

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
                store.redactEnabled ? LogXTheme.chipOn : Color.clear,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    store.redactEnabled ? LogXTheme.chipOnEdge : LogXTheme.line, lineWidth: 1
                )
            )
            .help("Yoqilsa ekran, ro'yxat, cURL, eksport va ulashishda token yashiriladi (⌘⇧T)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(LogXTheme.panel)
        .overlay(Divider().overlay(LogXTheme.divider), alignment: .top)
    }

    private func copy(_ text: String) {
        store.copy(text, what: tab.title)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    private func share(_ log: NetworkLog) {
        guard let data = ShareCardRenderer.pngData(log: log, tab: tab, redact: store.redactEnabled) else {
            store.presentError(title: "Rasm tayyorlanmadi", message: "Ulashish kartasi render bo'lmadi.")
            return
        }
        let dir = ShareScratch.directory()
        ShareScratch.purgeStale(in: dir)
        let url = dir.appendingPathComponent("logx-\(tab.rawValue)-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            store.presentError(title: "Rasm saqlanmadi", message: error.localizedDescription)
            return
        }
        shareHost.present(url: url)
    }
}

/// Bitta tabning tayyor ko'rinishi: matn, rangli NSAttributedString va topilmalar soni.
struct RenderedBody {
    struct Key: Equatable {
        var logKey: String
        var tab: DetailTab
        var redact: Bool
        var pretty: Bool
        var query: String
        var index: Int
    }

    /// Shundan katta tana ekranda qisqartiriladi (nusxa to'liq qoladi) — NSTextView
    /// megabaytlik JSON'ni layout qilib UI'ni muzlatmasin.
    static let displayLimitBytes = 512 * 1024

    var key: Key
    var text: String
    var attributed: NSAttributedString
    var matchCount: Int
    var activeRange: NSRange?
    var truncationNotice: String?

    static func make(log: NetworkLog, key: Key) -> RenderedBody {
        let body = JSONFormat.body(for: log, tab: key.tab, redact: key.redact, pretty: key.pretty)
        var display = body.isEmpty ? "—" : body
        var notice: String?
        if display.utf8.count > displayLimitBytes {
            let cut = String(decoding: display.utf8.prefix(displayLimitBytes), as: UTF8.self)
            let hidden = display.utf8.count - cut.utf8.count
            display = cut + "\n…"
            notice = "Ekranda \(ByteSize.label(displayLimitBytes)) ko'rsatildi, \(ByteSize.label(hidden)) qisqartirildi — «Nusxa» to'liq tanani beradi."
        }
        let matches = JSONFind.matches(display, query: key.query)
        let active = matches.isEmpty ? nil : min(max(key.index, 0), matches.count - 1)
        let rendered = JSONHighlighter.nsAttributedString(
            for: display,
            headers: key.tab == .headers,
            highlights: matches,
            activeIndex: active
        )
        return RenderedBody(
            key: key,
            text: body,
            attributed: rendered.text,
            matchCount: matches.count,
            activeRange: rendered.activeRange,
            truncationNotice: notice
        )
    }
}

/// Tana matni NSTextView'da: tanlash, o'rash/gorizontal aylanma va faol topilmaga scroll.
struct BodyTextView: NSViewRepresentable {
    var text: NSAttributedString
    var wrap: Bool
    var activeRange: NSRange?

    final class Coordinator {
        var lastText: NSAttributedString?
        var lastWrap: Bool?
        var lastActive: NSRange?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.textContainerInset = NSSize(width: 12, height: 14)
        textView.font = JSONHighlighter.bodyFont
        textView.textColor = JSONHighlighter.nsColor(.plain)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.setAccessibilityLabel("So'rov tanasi")
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView, let container = textView.textContainer else { return }
        let coord = context.coordinator
        if coord.lastWrap != wrap {
            coord.lastWrap = wrap
            if wrap {
                container.widthTracksTextView = true
                container.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                textView.setFrameSize(NSSize(width: scroll.contentSize.width, height: textView.frame.height))
                scroll.hasHorizontalScroller = false
            } else {
                container.widthTracksTextView = false
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                container.lineBreakMode = .byClipping
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = []
                scroll.hasHorizontalScroller = true
            }
            textView.layoutManager?.ensureLayout(for: container)
            textView.sizeToFit()
        }
        if coord.lastText !== text {
            coord.lastText = text
            textView.textStorage?.setAttributedString(text)
            coord.lastActive = nil
            if activeRange == nil {
                textView.scroll(.zero)
            }
        }
        if let activeRange, coord.lastActive != activeRange, activeRange.location + activeRange.length <= (textView.textStorage?.length ?? 0) {
            coord.lastActive = activeRange
            textView.scrollRangeToVisible(activeRange)
        }
    }
}

/// Ulashish PNG'lari alohida papkada turadi va bir soatdan eskilari o'chiriladi.
enum ShareScratch {
    static let maxAge: TimeInterval = 3600

    static func directory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("LogX-share", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func purgeStale(in dir: URL, now: Date = Date()) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for item in items where item.pathExtension == "png" {
            let modified = (try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? now
            if now.timeIntervalSince(modified) > maxAge {
                try? fm.removeItem(at: item)
            }
        }
    }
}

private struct ParamRowView: View {
    var key: String
    var value: String
    var isEven: Bool
    @State private var hovered = false
    @State private var copied = false
    @EnvironmentObject private var store: LogStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(LogXTheme.ok)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(LogXTheme.text2)
                .textSelection(.enabled)
            Spacer()
            if hovered || copied {
                Button {
                    store.copy(value, what: key)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9.5))
                        .foregroundStyle(copied ? LogXTheme.ok : LogXTheme.muted2)
                }
                .buttonStyle(.plain)
                .help(copied ? "Nusxalandi!" : "Qiymatni nusxalash")
                .accessibilityLabel("\(key) qiymatini nusxalash")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6.5)
        .background(hovered ? LogXTheme.panel2 : (isEven ? Color.clear : LogXTheme.panel.opacity(0.4)))
        .onHover { hovered = $0 }
    }
}

private struct ActionPillButton: View {
    var title: String
    var shortcut: [ShortcutGlyph.Part]? = nil
    var icon: String? = nil
    var isPrimary: Bool = false
    var help: String? = nil
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10.5))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: isPrimary ? .semibold : .medium))
                    .lineLimit(1)
                if let shortcut {
                    ShortcutGlyph(parts: shortcut)
                }
            }
            .foregroundStyle(hovered ? LogXTheme.text : (isPrimary ? LogXTheme.text : LogXTheme.muted))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(hovered ? LogXTheme.panel2 : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(hovered ? LogXTheme.line : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(LogXPressStyle())
        .onHover { hovered = $0 }
        .help(help ?? title)
    }
}

final class SharePickerHost: NSObject, ObservableObject, NSSharingServicePickerDelegate {
    weak var view: NSView? {
        didSet { flushPending() }
    }
    private var picker: NSSharingServicePicker?
    private var pendingURL: URL?

    func present(url: URL) {
        if show(url: url) { return }
        pendingURL = url
        DispatchQueue.main.async { [weak self] in
            self?.flushPending()
        }
    }

    private func flushPending() {
        guard let pendingURL else { return }
        if show(url: pendingURL) {
            self.pendingURL = nil
        }
    }

    @discardableResult
    private func show(url: URL) -> Bool {
        let attached = view.flatMap { $0.window == nil ? nil : $0 }
        let anchor = attached ?? NSApp.keyWindow?.contentView
        guard let anchor, anchor.window != nil else { return false }
        let picker = NSSharingServicePicker(items: [url])
        picker.delegate = self
        self.picker = picker
        picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        return true
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        picker = nil
    }
}

private struct SharePickerAnchor: NSViewRepresentable {
    @ObservedObject var host: SharePickerHost

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        host.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        host.view = nsView
    }
}
