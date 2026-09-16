import SwiftUI
import LogXCore

struct ReplayComposerView: View {
    @EnvironmentObject private var store: LogStore
    var log: NetworkLog

    @State private var method: String
    @State private var urlString: String
    @State private var headers: [HeaderItem]
    @State private var bodyText: String
    @State private var selectedTab: Tab = .body
    @State private var validationError: String?

    enum Tab: String, CaseIterable {
        case body = "Tana (Body)"
        case headers = "Sarlavhalar (Headers)"
    }

    struct HeaderItem: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    init(log: NetworkLog) {
        self.log = log
        let m = log.method.uppercased()
        _method = State(initialValue: (m == "?" || m.isEmpty) ? "GET" : m)
        _urlString = State(initialValue: log.url.isEmpty ? log.api : log.url)
        _bodyText = State(initialValue: log.requestBody ?? "")

        var initialHeaders: [HeaderItem] = []
        for key in log.requestHeaders.keys.sorted() {
            guard !CurlBuilder.droppedHeaders.contains(key.lowercased()) else { continue }
            if let value = log.requestHeaders[key] {
                initialHeaders.append(HeaderItem(key: key, value: value))
            }
        }
        _headers = State(initialValue: initialHeaders)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(LogXTheme.divider)

            methodAndURLRow
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(LogXTheme.panel)

            Divider().overlay(LogXTheme.divider)

            tabSelector
            Divider().overlay(LogXTheme.divider)

            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LogXTheme.bg)

            if let validationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(LogXType.ui(LogXType.meta))
                    Text(validationError)
                        .font(LogXType.ui(LogXType.meta))
                    Spacer()
                }
                .foregroundStyle(LogXTheme.err)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(LogXTheme.err.opacity(0.12))
            }

            Divider().overlay(LogXTheme.divider)
            bottomBar
        }
        .frame(minWidth: 640, idealWidth: 700, minHeight: 480, idealHeight: 540)
        .background(LogXTheme.panel)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperplane.fill")
                .font(LogXType.ui(LogXType.body, .semibold))
                .foregroundStyle(LogXTheme.accentLight)
            Text("So'rovni tahrirlash va qayta yuborish")
                .font(LogXType.ui(LogXType.title, .semibold))
                .foregroundStyle(LogXTheme.text)
            Spacer()
            Button {
                store.closeReplayComposer()
            } label: {
                Image(systemName: "xmark")
                    .font(LogXType.ui(LogXType.meta))
                    .foregroundStyle(LogXTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LogXTheme.well))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Yopish (Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LogXTheme.panel2)
    }

    private var methodAndURLRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $method) {
                Text("GET").tag("GET")
                Text("POST").tag("POST")
                Text("PUT").tag("PUT")
                Text("PATCH").tag("PATCH")
                Text("DELETE").tag("DELETE")
                Text("HEAD").tag("HEAD")
            }
            .labelsHidden()
            .frame(width: 95)

            TextField("https://api.example.uz/endpoint", text: $urlString)
                .textFieldStyle(.plain)
                .font(LogXType.mono(LogXType.body))
                .foregroundStyle(LogXTheme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(LogXTheme.well)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(LogXTheme.line, lineWidth: 1)
                )
                .autocorrectionDisabled(true)
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 12) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(LogXType.ui(LogXType.body, selectedTab == tab ? .semibold : .medium))
                        if tab == .headers {
                            Text("\(headers.count)")
                                .font(LogXType.mono(LogXType.caption, .bold))
                                .foregroundStyle(selectedTab == tab ? LogXTheme.accentLight : LogXTheme.muted2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(LogXTheme.well))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(selectedTab == tab ? LogXTheme.chipOn : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(selectedTab == tab ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(selectedTab == tab ? LogXTheme.text : LogXTheme.muted)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if selectedTab == .body && !bodyText.isEmpty {
                Button {
                    formatBodyJSON()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "wand.and.stars")
                            .font(LogXType.ui(LogXType.caption))
                        Text("JSON formatlash")
                            .font(LogXType.ui(LogXType.meta))
                    }
                    .foregroundStyle(LogXTheme.accentLight)
                }
                .buttonStyle(.plain)
            } else if selectedTab == .headers {
                Button {
                    headers.append(HeaderItem(key: "", value: ""))
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(LogXType.ui(LogXType.caption))
                        Text("Sarlavha qo'shish")
                            .font(LogXType.ui(LogXType.meta))
                    }
                    .foregroundStyle(LogXTheme.accentLight)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(LogXTheme.well)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .body:
            TextEditor(text: $bodyText)
                .font(LogXType.mono(LogXType.body))
                .scrollContentBackground(.hidden)
                .background(LogXTheme.bg)
                .padding(10)
        case .headers:
            ScrollView {
                VStack(spacing: 6) {
                    if headers.isEmpty {
                        Text("Sarlavhalar yo'q")
                            .font(LogXType.ui(LogXType.body))
                            .foregroundStyle(LogXTheme.muted)
                            .padding(.top, 30)
                    } else {
                        ForEach($headers) { $item in
                            HStack(spacing: 8) {
                                TextField("Kalit (masalan: Content-Type)", text: $item.key)
                                    .textFieldStyle(.plain)
                                    .font(LogXType.mono(LogXType.body))
                                    .foregroundStyle(LogXTheme.text)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(LogXTheme.well)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(LogXTheme.line, lineWidth: 1)
                                    )
                                    .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)
                                    .autocorrectionDisabled(true)

                                TextField("Qiymat", text: $item.value)
                                    .textFieldStyle(.plain)
                                    .font(LogXType.mono(LogXType.body))
                                    .foregroundStyle(LogXTheme.text)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(LogXTheme.well)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(LogXTheme.line, lineWidth: 1)
                                    )
                                    .frame(maxWidth: .infinity)
                                    .autocorrectionDisabled(true)

                                Button {
                                    headers.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(LogXType.ui(LogXType.body))
                                        .foregroundStyle(LogXTheme.err.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Sarlavhani o'chirish")
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Bekor qilish") {
                store.closeReplayComposer()
            }
            .buttonStyle(LogXPressStyle())
            .font(LogXType.ui(LogXType.body))
            .foregroundStyle(LogXTheme.text2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LogXTheme.well))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))

            Spacer()

            Button {
                sendReplay()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                        .font(LogXType.ui(LogXType.meta))
                    Text("Yuborish")
                        .font(LogXType.ui(LogXType.body, .semibold))
                }
                .foregroundStyle(LogXTheme.bg)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LogXTheme.accentLight))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(LogXTheme.accentLight, lineWidth: 1))
            }
            .buttonStyle(LogXPressStyle())
            .keyboardShortcut(.return, modifiers: .command)
            .help("So'rovni yuborish (⌘⏎)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LogXTheme.panel)
    }

    private func formatBodyJSON() {
        guard let data = bodyText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8) else {
            validationError = "Tana to'g'ri JSON emas — formatlab bo'lmadi"
            return
        }
        bodyText = str
        validationError = nil
    }

    private func sendReplay() {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            validationError = "URL manzili bo'sh bo'lishi mumkin emas"
            return
        }
        guard let url = URL(string: trimmedURL), url.host != nil else {
            validationError = "URL manzili yaroqsiz (masalan: https://domain.com/path)"
            return
        }

        var headerDict: [String: String] = [:]
        for item in headers {
            let k = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !k.isEmpty else { continue }
            headerDict[k] = item.value
        }

        let bodyToSend = bodyText.isEmpty ? nil : bodyText
        validationError = nil
        store.replayCustom(original: log, method: method, url: url, headers: headerDict, body: bodyToSend)
    }
}
