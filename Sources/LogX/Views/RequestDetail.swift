import AppKit
import SwiftUI
import LogXCore

struct RequestDetail: View {
    @EnvironmentObject private var store: LogStore
    @State private var tab: DetailTab = .response
    @State private var copied = false
    @StateObject private var shareHost = SharePickerHost()

    var body: some View {
        Group {
            if let log = store.selectedLog {
                detail(log)
                    .id(log.key)
                    .transition(.opacity)
            } else {
                Text("So‘rov tanlang")
                    .foregroundStyle(LogXTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.selectedKey)
        .background(LogXTheme.panel)
    }

    private func detail(_ log: NetworkLog) -> some View {
        let body = JSONFormat.body(for: log, tab: tab)
        let display = body.isEmpty ? "—" : body
        return VStack(alignment: .leading, spacing: 0) {
            header(log)
            Divider().overlay(LogXTheme.line)
            tabBar(copyText: display, log: log)
            ScrollView {
                highlighted(display, headers: tab == .headers)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
                    .textSelection(.enabled)
            }
            SharePickerAnchor(host: shareHost)
                .frame(width: 1, height: 1)
        }
    }

    private func header(_ log: NetworkLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(log.method)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LogXTheme.method)
                Text(log.responseCode.map(String.init) ?? "NET")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LogXTheme.status(log.statusClass))
                if let ms = log.durationMs {
                    Text(ms >= 1000 ? String(format: "%.1f s", Double(ms) / 1000) : "\(ms) ms")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(LogXTheme.muted)
                }
                Spacer()
                iconButton(copied ? "checkmark" : "doc.on.doc", help: "Nusxa") {
                    copy(JSONFormat.body(for: log, tab: tab))
                }
                iconButton(store.favoriteKeys.contains(log.key) ? "star.fill" : "star", help: "Sevimli") {
                    store.toggleFavorite(log.key)
                }
                iconButton("square.and.arrow.up", help: "Share rasm") {
                    share(log)
                }
            }
            Text(log.url.isEmpty ? log.api : log.url)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(LogXTheme.text)
                .textSelection(.enabled)
            HStack(spacing: 12) {
                meta("App", log.appLabel)
                meta("Device", log.fieldDeviceLabel)
                if let env = log.environment, !env.isEmpty {
                    meta("Env", [env, log.flavor, log.appVersion].compactMap { $0 }.joined(separator: " · "))
                }
            }
            HStack(spacing: 12) {
                if let feature = log.feature, !feature.isEmpty {
                    meta("Feature", log.moduleName ?? feature)
                }
                let pinfl = log.userInfoPinfl ?? log.assistantJshshir
                if let pinfl, !pinfl.isEmpty { meta("PINFL", pinfl) }
                if let sid = log.sessionId, !sid.isEmpty { meta("Session", sid) }
                let did = log.requestHeaders["device-id"]
                if let did, !did.isEmpty { meta("device-id", did) }
            }
            if let msg = log.responseBodyMessage ?? log.responseMessage, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundStyle(LogXTheme.warn)
                    .lineLimit(3)
            }
        }
        .padding(14)
    }

    private func tabBar(copyText: String, log: NetworkLog) -> some View {
        HStack(spacing: 6) {
            ForEach(DetailTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        tab = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 12, weight: tab == item ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(tab == item ? LogXTheme.select : Color.clear))
                        .overlay(
                            Capsule().stroke(tab == item ? LogXTheme.ember.opacity(0.5) : LogXTheme.line, lineWidth: 1)
                        )
                        .foregroundStyle(tab == item ? LogXTheme.text : LogXTheme.muted)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button("Copy") { copy(copyText) }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LogXTheme.ember)
            Button("Share") { share(log) }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LogXTheme.ember)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func highlighted(_ text: String, headers: Bool) -> Text {
        if headers {
            return Text(text).font(.system(size: 12, design: .monospaced)).foregroundStyle(LogXTheme.text)
        }
        var out = Text("")
        for span in JSONFormat.highlight(text) {
            out = out + Text(span.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(spanColor(span.kind))
        }
        return out
    }

    private func spanColor(_ kind: JSONSpanKind) -> Color {
        switch kind {
        case .key: return Color(red: 0.49, green: 0.91, blue: 0.53)
        case .string: return Color(red: 0.65, green: 0.84, blue: 1.0)
        case .number: return LogXTheme.method
        case .boolNull: return LogXTheme.err
        case .punct: return LogXTheme.muted
        case .plain: return LogXTheme.text
        }
    }

    private func meta(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(LogXTheme.muted)
            Text(v)
                .font(.system(size: 12))
                .foregroundStyle(LogXTheme.text)
        }
    }

    private func iconButton(_ system: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LogXTheme.muted)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 6).stroke(LogXTheme.line))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text.isEmpty ? "—" : text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    private func share(_ log: NetworkLog) {
        guard let data = ShareCardRenderer.pngData(log: log, tab: tab) else { return }
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("logx-\(tab.rawValue).png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
        shareHost.present(url: url)
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
