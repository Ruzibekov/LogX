import AppKit
import Combine
import SwiftUI
import LogXCore

struct RequestList: View {
    @EnvironmentObject private var store: LogStore
    @State private var now = Date()
    @State private var listWidth: CGFloat = 560
    @FocusState private var listFocused: Bool
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var showAppColumn: Bool {
        store.selectedAppId == "all" && store.hasMultipleLiveApps && listWidth >= 520
    }

    private var showTimeColumn: Bool {
        listWidth >= 430
    }

    var body: some View {
        VStack(spacing: 0) {
            RequestFilterBar()
            Divider().overlay(LogXTheme.divider)
            if let banner = store.banner, !store.visibleLogs.isEmpty {
                noticeStrip(banner)
                Divider().overlay(LogXTheme.divider)
            }
            if store.isLoading {
                VStack(spacing: 10) {
                    ProgressView().scaleEffect(0.9)
                    Text("Yuklanmoqda…").font(LogXType.ui(LogXType.body)).foregroundStyle(LogXTheme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.visibleLogs.isEmpty {
                RequestEmptyView()
            } else {
                list
            }
        }
        .background(LogXTheme.bg)
        .background(GeometryReader { geo in Color.clear.preference(key: RequestListWidthKey.self, value: geo.size.width) })
        .onPreferenceChange(RequestListWidthKey.self) { width in
            if width > 0 && abs(listWidth - width) > 4 { listWidth = width }
        }
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                ToastView(toast: toast) { store.dismissToast() }
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.toast)
        .onReceive(ticker) { now = $0 }
    }

    private func noticeStrip(_ text: String) -> some View {
        let command = text.split(separator: "—").map { $0.trimmingCharacters(in: .whitespaces) }.first(where: { $0.hasPrefix("bash ") })
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10.5, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .medium)).lineLimit(2).textSelection(.enabled)
            Spacer(minLength: 4)
            if let command {
                Button("Buyruqni nusxalash") { store.copy(command, what: "buyruq") }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(LogXTheme.accentLight)
            }
            Button { store.dismissBanner() } label: {
                Image(systemName: "xmark").font(.system(size: 9.5, weight: .bold)).foregroundStyle(LogXTheme.muted).padding(4)
            }
            .buttonStyle(.plain).help("Xabarni yopish").accessibilityLabel("Xabarni yopish")
        }
        .foregroundStyle(LogXTheme.warn).padding(.horizontal, 12).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading).background(LogXTheme.warn.opacity(0.1))
    }

    private var listScope: String {
        "\(store.selectedAppId)|\(store.selectedSerial ?? "")"
    }

    private func hostHeader(_ host: String, count: Int) -> some View {
        Button { store.selectHost(host) } label: {
            HStack(spacing: 10) {
                Text(host)
                    .font(LogXType.mono(LogXType.caption, .semibold))
                    .foregroundStyle(store.selectedHost == host ? LogXTheme.accent : LogXTheme.muted)
                    .lineLimit(1)
                Rectangle()
                    .fill(LogXTheme.divider)
                    .frame(height: 1)
                Text("\(count)")
                    .font(LogXType.mono(LogXType.caption))
                    .foregroundStyle(LogXTheme.muted2)
            }
            .padding(.horizontal, 14)
            .frame(height: 26)
            .background(LogXTheme.bg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(store.selectedHost == host ? "Host filtrini olib tashlash" : "Faqat \(host)")
    }

    private var list: some View {
        VStack(spacing: 0) {
            LatencyTimelineView()
            ScrollViewReader { proxy in
                List(ListGrouping.rows(store.visibleLogs)) { row in
                    switch row {
                    case let .host(name, count):
                        hostHeader(name, count: count)
                            .id(row.id)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    case let .log(log):
                        RequestRow(
                            log: log,
                            selected: store.selectedKey == log.key,
                            now: now,
                            showAppColumn: showAppColumn,
                            showTimeColumn: showTimeColumn
                        )
                            .id(log.key)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .contextMenu { rowMenu(log) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 52)
                .focusable()
                .focusEffectDisabled()
                .focused($listFocused)
                .simultaneousGesture(TapGesture().onEnded { listFocused = true })
                .onMoveCommand { dir in
                    if dir == .up { store.moveSelection(by: -1) }
                    else if dir == .down { store.moveSelection(by: 1) }
                }
                .onExitCommand { store.clearSelection() }
                .onReceive(NotificationCenter.default.publisher(for: LogXNotice.focusList)) { _ in
                    listFocused = true
                    if store.selectedKey == nil { store.moveSelection(by: 1) }
                }
                .onKeyPress(.upArrow) { store.moveSelection(by: -1); return .handled }
                .onKeyPress(.downArrow) { store.moveSelection(by: 1); return .handled }
                .onChange(of: store.selectedKey) { _, key in
                    guard let key, store.visibleLogs.contains(where: { $0.key == key }) else { return }
                    proxy.scrollTo(key, anchor: store.followLatest ? .top : .center)
                }
                .id(listScope)
            }
        }
    }

    @ViewBuilder
    private func rowMenu(_ log: NetworkLog) -> some View {
        Button(store.query == log.pathOnly ? "Endpoint filtrini olib tashlash" : "Shu endpointni filtrlash") { store.filterEndpoint(log) }
        if !log.hostLabel.isEmpty {
            Button(store.selectedHost == log.hostLabel ? "Host filtrini olib tashlash" : "Faqat shu host") { store.selectHost(log.hostLabel) }
        }
        Divider()
        Button("Qayta yuborish") { store.replay(log) }
            .disabled(!store.canReplay(log))
        Divider()
        Button(store.diffAnchorKey == log.key ? "A belgisini olib tashlash" : "Solishtirish uchun belgilash (A)") { store.toggleDiffAnchor(log) }
        if let anchor = store.diffAnchor, anchor.key != log.key {
            Button("A bilan solishtirish · \(anchor.method) \(anchor.pathOnly)") { store.compareWithAnchor(log) }
        }
        if store.previousSameEndpoint(of: log) != nil {
            Button("Oldingi bir xil so'rov bilan solishtirish") { store.compareWithPrevious(log) }
        }
        Divider()
        Button("URL'ni nusxalash") { store.copy(store.shareableURL(log), what: "URL") }
        Button("Qatorni nusxalash") {
            store.copy("\(log.method) \(log.hostLabel) \(store.displayPath(log)) \(log.appShortLabel) \(RelativeTime.clock(ts: log.ts))", what: "qator")
        }
        Button("Yo'lni nusxalash") { store.copy(store.displayPath(log), what: "yo'l") }
        Button("cURL sifatida nusxalash") {
            store.copy(CurlBuilder.command(for: log, redact: store.redactEnabled), what: "cURL")
        }
        Button("So'rov bodyni nusxalash") {
            store.copy(store.redactEnabled ? (Redactor.redactBody(log.requestBody) ?? "") : (log.requestBody ?? ""), what: "so'rov tanasi")
        }
        Button("Javobni nusxalash") {
            store.copy(store.redactEnabled ? (Redactor.redactBody(log.responseBody) ?? "") : (log.responseBody ?? ""), what: "javob")
        }
        Button("Sarlavhalarni nusxalash") {
            let req = store.redactEnabled ? Redactor.mask(log.requestHeaders) : log.requestHeaders
            let res = store.redactEnabled ? Redactor.mask(log.responseHeaders) : log.responseHeaders
            store.copy(JSONFormat.headersText(request: req, response: res), what: "sarlavhalar")
        }
        Button("HAR nusxalash") {
            let data = SessionExport.har(logs: [log], redact: store.redactEnabled)
            store.copy(String(data: data, encoding: .utf8) ?? "", what: "HAR")
        }
        Divider()
        Button(store.isFavorite(log.key) ? "Sevimlilardan o'chirish" : "Sevimlilarga qo'shish") {
            store.toggleFavorite(log.key)
        }
    }
}

enum CopyBox {
    static func plainText(_ raw: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(raw, forType: .string)
    }
}

struct ToastView: View {
    var toast: Toast
    var dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(toast.text).font(.system(size: 11.5, weight: .medium)).foregroundStyle(LogXTheme.text).lineLimit(1)
            if let title = toast.actionTitle, let action = toast.action {
                Button(title) { action(); dismiss() }
                    .buttonStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(LogXTheme.accentLight)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(LogXTheme.panel2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct RequestListWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 560
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

