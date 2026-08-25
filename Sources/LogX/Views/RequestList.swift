import AppKit
import SwiftUI
import LogXCore

struct RequestList: View {
    @EnvironmentObject private var store: LogStore
    @State private var now = Date()
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            filters
            Divider().overlay(LogXTheme.divider)
            if store.isLoading {
                VStack(spacing: 10) {
                    ProgressView().scaleEffect(0.9)
                    Text("Yuklanmoqda…").font(.system(size: 12)).foregroundStyle(LogXTheme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.visibleLogs.isEmpty {
                empty
            } else {
                list
            }
            liveBar
        }
        .background(LogXTheme.bg)
        .onReceive(ticker) { now = $0 }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                segment("Barchasi", count: store.statusCount(.all), color: LogXTheme.text,
                        active: !store.errorsOnly && store.status == .all) {
                    store.selectStatus(.all)
                }
                ForEach([StatusClass.ok2xx, .redirect3xx, .err4xx, .err5xx, .net], id: \.self) { item in
                    segment(item.title, count: store.statusCount(item), color: LogXTheme.status(item),
                            active: !store.errorsOnly && store.status == item) {
                        store.selectStatus(item)
                    }
                }
                errorPill
                Spacer(minLength: 6)
                if store.hasActiveFilter {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            store.clearFilters()
                        }
                    } label: {
                        Text("Tozalash")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(LogXTheme.accentLight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(LogXTheme.accent.opacity(0.16)))
                            .overlay(Capsule().stroke(LogXTheme.accent.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Barcha filtrlarni tozalash")
                }
                Text("\(store.visibleLogs.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(LogXTheme.well))
                    .overlay(Capsule().stroke(LogXTheme.line, lineWidth: 1))
            }
            HStack(spacing: 1) {
                ForEach(["ALL", "GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { m in
                    methodButton(m)
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 6).fill(LogXTheme.well).overlay(RoundedRectangle(cornerRadius: 6).stroke(LogXTheme.line, lineWidth: 1)))
            HStack(spacing: 5) {
                noiseToggle
                slowPill
                if store.uniqueHosts.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(store.uniqueHosts, id: \.self) { host in
                                hostChip(host)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: store.status)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: store.selectedMethod)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.hasActiveFilter)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: store.hideNoise)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: store.slowOnly)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: store.selectedHost)
    }

    private func methodButton(_ method: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                store.selectMethod(method)
            }
        } label: {
            Text(method)
                .font(.system(size: 9.5, weight: store.selectedMethod == method ? .bold : .medium, design: .monospaced))
                .foregroundStyle(store.selectedMethod == method ? (method == "ALL" ? LogXTheme.text : LogXTheme.methodColor(method)) : LogXTheme.muted2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4.5).fill(store.selectedMethod == method ? LogXTheme.panel2 : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 4.5).stroke(store.selectedMethod == method ? LogXTheme.line : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var noiseToggle: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                store.toggleHideNoise()
            }
        } label: {
            Text("Shovqin")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(store.hideNoise ? LogXTheme.accentLight : LogXTheme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(store.hideNoise ? LogXTheme.accent.opacity(0.16) : Color.clear))
                .overlay(Capsule().stroke(store.hideNoise ? LogXTheme.accent.opacity(0.4) : LogXTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Analytics, health, ping va rasm so'rovlarini yashirish")
    }

    private var slowPill: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                store.toggleSlowOnly()
            }
        } label: {
            Text("Sekin")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(store.slowOnly ? LogXTheme.warn : LogXTheme.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(store.slowOnly ? LogXTheme.warn.opacity(0.18) : Color.clear))
                .overlay(Capsule().stroke(store.slowOnly ? LogXTheme.warn.opacity(0.5) : LogXTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Faqat ≥ 800 ms")
    }

    private func hostChip(_ host: String) -> some View {
        let active = store.selectedHost == host
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                store.selectHost(host)
            }
        } label: {
            Text(host)
                .font(.system(size: 10, weight: active ? .semibold : .medium, design: .monospaced))
                .foregroundStyle(active ? LogXTheme.text : LogXTheme.muted)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(active ? LogXTheme.accent.opacity(0.18) : Color.clear))
                .overlay(Capsule().stroke(active ? LogXTheme.accent.opacity(0.45) : LogXTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(host)
    }

    private var errorPill: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                store.toggleErrorsOnly()
            }
        } label: {
            HStack(spacing: 4) {
                Text("⚠").font(.system(size: 10, weight: .bold))
                Text("\(store.errorCount)").font(.system(size: 10.5, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(store.errorsOnly ? LogXTheme.err.opacity(0.2) : (store.errorCount > 0 ? LogXTheme.err.opacity(0.08) : Color.clear)))
            .overlay(Capsule().stroke(store.errorsOnly ? LogXTheme.err.opacity(0.7) : (store.errorCount > 0 ? LogXTheme.err.opacity(0.3) : LogXTheme.line), lineWidth: 1))
            .foregroundStyle(store.errorsOnly || store.errorCount > 0 ? LogXTheme.err : LogXTheme.muted)
        }
        .buttonStyle(.plain)
        .help("Faqat xatolar: 4xx + 5xx + NET")
    }

    private func segment(_ title: String, count: Int, color: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 11.5, weight: active ? .semibold : .medium))
                Text("\(count)").font(.system(size: 10.5, weight: active ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(active ? color : LogXTheme.muted2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(active ? (color == LogXTheme.text ? LogXTheme.accent.opacity(0.18) : color.opacity(0.15)) : Color.clear))
            .overlay(Capsule().stroke(active ? (color == LogXTheme.text ? LogXTheme.accent.opacity(0.5) : color.opacity(0.4)) : LogXTheme.line, lineWidth: 1))
            .foregroundStyle(active ? LogXTheme.text : LogXTheme.muted)
        }
        .buttonStyle(.plain)
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("METOD").frame(width: 58, alignment: .leading)
            Text("KOD").frame(width: 44, alignment: .leading)
            Text("MANZIL").frame(maxWidth: .infinity, alignment: .leading)
            Text("DAVOM").frame(width: 58, alignment: .trailing)
            Text("QACHON").frame(width: 58, alignment: .trailing)
            Text("ILOVA").frame(width: 58, alignment: .trailing)
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
            List(store.visibleLogs, selection: Binding(
                get: { store.selectedKey },
                set: { key in
                    if let key, let log = store.visibleLogs.first(where: { $0.key == key }) {
                        store.selectLog(log)
                    }
                }
            )) { log in
                RequestRow(log: log, selected: store.selectedKey == log.key, now: now)
                    .tag(log.key)
                    .listRowBackground(store.selectedKey == log.key ? LogXTheme.accent.opacity(0.13) : LogXTheme.bg)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .contextMenu { rowMenu(log) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 40)
        }
    }

    @ViewBuilder
    private func rowMenu(_ log: NetworkLog) -> some View {
        Button("URL'ni nusxalash") { CopyBox.plainText(log.url.isEmpty ? log.api : log.url) }
        Button("Qatorni nusxalash") {
            CopyBox.plainText("\(log.method) \(log.hostLabel) \(log.pathLabel) \(log.appShortLabel) \(RelativeTime.clock(ts: log.ts))")
        }
        Button("Yo'lni nusxalash") { CopyBox.plainText(log.pathLabel) }
        Button("cURL sifatida nusxalash") {
            CopyBox.plainText(CurlBuilder.command(for: log, redact: store.redactEnabled))
        }
        Button("So'rov bodyni nusxalash") { CopyBox.plainText(log.requestBody ?? "") }
        Button("Javobni nusxalash") { CopyBox.plainText(log.responseBody ?? "") }
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
        Button(store.favoriteKeys.contains(log.key) ? "Sevimlilardan o'chirish" : "Sevimlilarga qo'shish") {
            store.toggleFavorite(log.key)
        }
    }

    private var liveBar: some View {
        HStack(spacing: 8) {
            ConnectionDot(tint: liveBarTint, pulsing: store.connection == .live)
            Text(store.connection.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(liveBarTint)
            Text(liveBarSummary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LogXTheme.muted2)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                shortcutBadge("↑↓")
                shortcutBadge("⌘F")
                shortcutBadge("⌘P")
                shortcutBadge("⌘⇧C")
                shortcutBadge("⌘K")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(LogXTheme.panel)
        .overlay(Divider().overlay(LogXTheme.divider), alignment: .top)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.connection)
    }

    private var liveBarSummary: String {
        var parts = ["\(store.allLogs.count) so'rov"]
        if store.isPaused, store.skippedWhilePaused > 0 {
            parts.append("\(store.skippedWhilePaused) o'tkazildi")
        }
        parts.append("oxirgisi \(RelativeTime.label(ts: store.lastActivityTs, now: now))")
        return parts.joined(separator: " · ")
    }

    private var liveBarTint: Color {
        switch store.connection {
        case .live: return LogXTheme.ok
        case .reconnecting, .paused, .connecting, .booting, .noDevice: return LogXTheme.warn
        case .serverDown: return LogXTheme.err
        }
    }

    private func shortcutBadge(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(LogXTheme.muted2)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 3.5))
            .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(LogXTheme.line, lineWidth: 1))
    }

    private var empty: some View {
        RequestEmptyView() // Filterga mos so'rov yo'q va bo'sh holatlar
    }
}

enum CopyBox {
    static func plainText(_ raw: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(raw.isEmpty ? "—" : raw, forType: .string)
    }
}
