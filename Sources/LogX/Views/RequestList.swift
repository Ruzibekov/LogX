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
        .onReceive(ticker) { now = $0 }
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
        Button("URL'ni nusxalash") { CopyBox.plainText(store.shareableURL(log)) }
        Button("Qatorni nusxalash") {
            CopyBox.plainText("\(log.method) \(log.hostLabel) \(store.displayPath(log)) \(log.appShortLabel) \(RelativeTime.clock(ts: log.ts))")
        }
        Button("Yo'lni nusxalash") { CopyBox.plainText(store.displayPath(log)) }
        Button("cURL sifatida nusxalash") {
            CopyBox.plainText(CurlBuilder.command(for: log, redact: store.redactEnabled))
        }
        Button("So'rov bodyni nusxalash") {
            CopyBox.plainText(store.redactEnabled ? (Redactor.redactBody(log.requestBody) ?? "") : (log.requestBody ?? ""))
        }
        Button("Javobni nusxalash") {
            CopyBox.plainText(store.redactEnabled ? (Redactor.redactBody(log.responseBody) ?? "") : (log.responseBody ?? ""))
        }
        Button("Sarlavhalarni nusxalash") {
            let req = store.redactEnabled ? Redactor.mask(log.requestHeaders) : log.requestHeaders
            let res = store.redactEnabled ? Redactor.mask(log.responseHeaders) : log.responseHeaders
            CopyBox.plainText(JSONFormat.headersText(request: req, response: res))
        }
        Button("HAR nusxalash") {
            let data = SessionExport.har(logs: [log], redact: store.redactEnabled)
            CopyBox.plainText(String(data: data, encoding: .utf8) ?? "")
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
        pb.setString(raw.isEmpty ? "—" : raw, forType: .string)
    }
}
