import AppKit
import SwiftUI
import LogXCore

struct RequestDetail: View {
    @EnvironmentObject private var store: LogStore
    @State private var tab: DetailTab = .response
    @State private var copied = false
    @AppStorage("logx.wrapBody") private var wrapBody = true
    @StateObject private var shareHost = SharePickerHost()

    var body: some View {
        Group {
            if let log = store.selectedLog {
                detail(log)
                    .transition(.opacity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 32))
                        .foregroundStyle(LogXTheme.muted2)
                    Text("So‘rov tanlang")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LogXTheme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.selectedKey)
        .background(LogXTheme.panel)
    }

    private func detail(_ log: NetworkLog) -> some View {
        let body = JSONFormat.body(for: log, tab: tab, redact: store.redactEnabled)
        let display = body.isEmpty ? "—" : body
        return VStack(alignment: .leading, spacing: 0) {
            DetailHeader(
                log: log,
                tab: tab,
                copied: copied,
                onCopy: { copy(JSONFormat.body(for: log, tab: tab, redact: store.redactEnabled)) },
                onShare: { share(log) }
            )
            Divider().overlay(LogXTheme.divider)
            tabBar(log: log)
            Divider().overlay(LogXTheme.divider)
            ScrollView(wrapBody ? [.vertical] : [.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    if tab == .params && !log.queryParams.isEmpty {
                        paramsTable(log.queryParams)
                    } else {
                        jsonBody(display, headers: tab == .headers)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LogXTheme.well)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(LogXTheme.line, lineWidth: 1)
                        )
                )
                .padding(10)
            }
            actionBar(log)
            SharePickerAnchor(host: shareHost)
                .frame(width: 1, height: 1)
        }
    }

    @ViewBuilder
    private func jsonBody(_ display: String, headers: Bool) -> some View {
        let text = Text(JSONHighlighter.attributedString(for: display, headers: headers))
            .textSelection(.enabled)
            .padding(14)
        if wrapBody {
            text.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            text.fixedSize(horizontal: true, vertical: false)
        }
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
                        tab = item
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
                                    Capsule().fill(tab == item ? LogXTheme.accent.opacity(0.3) : LogXTheme.well)
                                )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Capsule().fill(tab == item ? LogXTheme.accent.opacity(0.18) : Color.clear))
                    .overlay(
                        Capsule().stroke(tab == item ? LogXTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(tab == item ? LogXTheme.text : LogXTheme.muted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(tabShortcut(item), modifiers: .command)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    wrapBody.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: wrapBody ? "text.alignleft" : "arrow.left.and.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(wrapBody ? "Qator" : "Lenta")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(wrapBody ? LogXTheme.text : LogXTheme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(wrapBody ? LogXTheme.accent.opacity(0.18) : Color.clear))
                .overlay(Capsule().stroke(wrapBody ? LogXTheme.accent.opacity(0.45) : LogXTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help(wrapBody ? "Uzun qatorni gorizontal aylanma qilish" : "Matnni oynaga sig'dirish")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(LogXTheme.well)
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
            ActionPillButton(title: "Nusxa", shortcut: "⌘C", isPrimary: true) {
                copy(JSONFormat.body(for: log, tab: tab, redact: store.redactEnabled))
            }

            ActionPillButton(title: "cURL", shortcut: "⌘⇧C", help: "cURL buyrug'ini nusxalash (⌘⇧C)") {
                CopyBox.plainText(CurlBuilder.command(for: log, redact: store.redactEnabled))
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            ActionPillButton(title: "Ulashish", icon: "square.and.arrow.up") {
                share(log)
            }

            Spacer(minLength: 0)

            Toggle(isOn: Binding(
                get: { store.redactEnabled },
                set: { store.redactEnabled = $0 }
            )) {
                Text("Yashirish")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(store.redactEnabled ? LogXTheme.accentLight : LogXTheme.muted)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                store.redactEnabled ? LogXTheme.accent.opacity(0.16) : Color.clear,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    store.redactEnabled ? LogXTheme.accent.opacity(0.5) : LogXTheme.line, lineWidth: 1
                )
            )
            .help("Ekran, cURL va ulashishda token yashiriladi")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(LogXTheme.panel)
        .overlay(Divider().overlay(LogXTheme.divider), alignment: .top)
    }

    private func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text.isEmpty ? "—" : text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    private func share(_ log: NetworkLog) {
        guard let data = ShareCardRenderer.pngData(log: log, tab: tab, redact: store.redactEnabled) else { return }
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("logx-\(tab.rawValue)-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
        shareHost.present(url: url)
    }
}

private struct ParamRowView: View {
    var key: String
    var value: String
    var isEven: Bool
    @State private var hovered = false
    @State private var copied = false

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
                    CopyBox.plainText(value)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9.5))
                        .foregroundStyle(copied ? LogXTheme.ok : LogXTheme.muted2)
                }
                .buttonStyle(.plain)
                .help(copied ? "Nusxalandi!" : "Qiymatni nusxalash")
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
    var shortcut: String? = nil
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
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(LogXTheme.muted2)
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
        .buttonStyle(.plain)
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
