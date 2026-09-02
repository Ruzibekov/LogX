import AppKit
import SwiftUI
import LogXCore

struct RequestList: View {
    @EnvironmentObject private var store: LogStore
    @State private var now = Date()
    @FocusState private var listFocused: Bool
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

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
                    Text("Yuklanmoqda…").font(.system(size: 12)).foregroundStyle(LogXTheme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.visibleLogs.isEmpty {
                RequestEmptyView()
            } else {
                list
            }
            RequestLiveBar(now: now)
        }
        .background(LogXTheme.bg)
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

    /// Oqim/monitor xabari ro'yxat to'la bo'lganda ham ko'rinadi; buyruq bo'lsa bir bosishda nusxalanadi.
    private func noticeStrip(_ text: String) -> some View {
        let command = text.split(separator: "—").map { $0.trimmingCharacters(in: .whitespaces) }.first(where: { $0.hasPrefix("bash ") })
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10.5, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer(minLength: 4)
            if let command {
                Button("Buyruqni nusxalash") { store.copy(command, what: "buyruq") }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LogXTheme.accentLight)
            }
            Button {
                store.dismissBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(LogXTheme.muted)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Xabarni yopish")
            .accessibilityLabel("Xabarni yopish")
        }
        .foregroundStyle(LogXTheme.warn)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LogXTheme.warn.opacity(0.1))
    }

    private var listScope: String {
        "\(store.selectedAppId)|\(store.selectedSerial ?? "")"
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("METOD").frame(width: 58, alignment: .leading)
            Text("KOD").frame(width: 44, alignment: .leading)
            Text("MANZIL").frame(maxWidth: .infinity, alignment: .leading)
            Text("DAVOM").frame(width: 58, alignment: .trailing)
            Text("QACHON").frame(width: 58, alignment: .trailing)
            Text("ILOVA").frame(width: 76, alignment: .trailing)
            Color.clear.frame(width: 24, height: 1)
        }
        .font(.system(size: 9.5, weight: .bold))
        .tracking(0.9)
        .foregroundStyle(LogXTheme.muted2)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(LogXTheme.well)
    }

    private var list: some View {
        VStack(spacing: 0) {
            columnHeader
            Divider().overlay(LogXTheme.divider)
            ScrollViewReader { proxy in
                List(store.visibleLogs) { log in
                    RequestRow(log: log, selected: store.selectedKey == log.key, now: now)
                        .id(log.key)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .contextMenu { rowMenu(log) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 40)
                .focusable()
                .focusEffectDisabled()
                .focused($listFocused)
                .simultaneousGesture(TapGesture().onEnded { listFocused = true })
                .onMoveCommand { direction in
                    switch direction {
                    case .up: store.moveSelection(by: -1)
                    case .down: store.moveSelection(by: 1)
                    default: break
                    }
                }
                .onExitCommand { store.clearSelection() }
                .onReceive(NotificationCenter.default.publisher(for: LogXNotice.focusList)) { _ in
                    listFocused = true
                    if store.selectedKey == nil { store.moveSelection(by: 1) }
                }
                .onKeyPress(.upArrow) { store.moveSelection(by: -1); return .handled }
                .onKeyPress(.downArrow) { store.moveSelection(by: 1); return .handled }
                .onChange(of: store.selectedKey) { _, key in
                    guard !store.followLatest, let key,
                          store.visibleLogs.contains(where: { $0.key == key }) else { return }
                    proxy.scrollTo(key, anchor: .center)
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
            Text(toast.text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(LogXTheme.text)
                .lineLimit(1)
            if let title = toast.actionTitle, let action = toast.action {
                Button(title) {
                    action()
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(LogXTheme.accentLight)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(LogXTheme.panel2, in: Capsule())
        .overlay(Capsule().stroke(LogXTheme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
