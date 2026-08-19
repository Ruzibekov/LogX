import SwiftUI
import LogXCore

struct RequestList: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        VStack(spacing: 0) {
            filters
            Divider().overlay(LogXTheme.line)
            if store.isLoading {
                ProgressView("Yuklanmoqda…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(LogXTheme.muted)
            } else if store.visibleLogs.isEmpty {
                empty
            } else {
                list
            }
        }
        .background(LogXTheme.bg)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    chip("Barchasi", selected: store.selectedAppId == "all") {
                        store.selectApp("all")
                    }
                    ForEach(store.apps) { app in
                        chip(app.shortLabel, selected: store.selectedAppId == app.id) {
                            store.selectApp(app.id)
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 10, for: .scrollContent)
            HStack(spacing: 4) {
                ForEach(StatusClass.allCases, id: \.self) { item in
                    chip("\(item.title) \(store.statusCount(item))", selected: store.status == item) {
                        store.selectStatus(item)
                    }
                }
                chip("★ \(store.favoriteKeys.count)", selected: store.favoritesOnly) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        store.toggleFavoritesOnly()
                    }
                }
                Spacer()
                Text("\(store.visibleLogs.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted)
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 10)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: store.selectedAppId)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: store.status)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(selected ? LogXTheme.select : Color.clear)
                )
                .overlay(
                    Capsule().stroke(selected ? LogXTheme.ember.opacity(0.5) : LogXTheme.line, lineWidth: 1)
                )
                .foregroundStyle(selected ? LogXTheme.text : LogXTheme.muted)
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        List(store.visibleLogs, selection: Binding(
            get: { store.selectedKey },
            set: { key in
                if let key, let log = store.visibleLogs.first(where: { $0.key == key }) {
                    store.selectLog(log)
                }
            }
        )) { log in
            RequestRow(log: log, selected: store.selectedKey == log.key)
                .tag(log.key)
                .listRowBackground(store.selectedKey == log.key ? LogXTheme.select : LogXTheme.bg)
                .onTapGesture { store.selectLog(log) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            if store.allLogs.isEmpty {
                Text(store.banner ?? "So‘rov yo‘q")
                    .font(.system(size: 14, weight: .medium))
                Text("Ilovani oching yoki 8787 ni tekshiring.")
                    .font(.system(size: 12))
                    .foregroundStyle(LogXTheme.muted)
            } else if store.selectedAppId != "all"
                || store.status != .all
                || store.favoritesOnly
                || !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Text("Filterga mos so‘rov yo‘q")
                    .font(.system(size: 14, weight: .medium))
                Text("Jami \(store.allLogs.count) ta live — boshqa ilova yoki status.")
                    .font(.system(size: 12))
                    .foregroundStyle(LogXTheme.muted)
                    .multilineTextAlignment(.center)
                Button("Barcha ilovalar") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        store.selectApp("all")
                        store.selectStatus(.all)
                        store.applyQuery("")
                        if store.favoritesOnly { store.toggleFavoritesOnly() }
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LogXTheme.ember)
                .padding(.top, 4)
            } else {
                Text("Bu USB da live so‘rov yo‘q")
                    .font(.system(size: 14, weight: .medium))
                Text("Jami \(store.allLogs.count) ta live — boshqa ulangan qurilma.")
                    .font(.system(size: 12))
                    .foregroundStyle(LogXTheme.muted)
                    .multilineTextAlignment(.center)
                Button("Barchasini ko‘rish") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        store.selectAllDevices()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LogXTheme.ember)
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
}

private struct RequestRow: View {
    var log: NetworkLog
    var selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(log.method)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LogXTheme.method)
                .frame(width: 52, alignment: .leading)
            Text(log.responseCode.map(String.init) ?? "NET")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(LogXTheme.status(log.statusClass))
                .frame(width: 40, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(log.pathLabel)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(LogXTheme.text)
                    .lineLimit(1)
                if !log.hostLabel.isEmpty {
                    Text(log.hostLabel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(LogXTheme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(duration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(durationColor)
                .frame(width: 64, alignment: .trailing)
            Text(timeLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LogXTheme.muted)
                .frame(width: 44, alignment: .trailing)
            Text(app)
                .font(.system(size: 11))
                .foregroundStyle(LogXTheme.muted)
                .frame(width: 78, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }

    private var duration: String {
        guard let ms = log.durationMs else { return "—" }
        if ms >= 1000 { return String(format: "%.1f s", Double(ms) / 1000) }
        return "\(ms) ms"
    }

    private var durationColor: Color {
        guard let ms = log.durationMs else { return LogXTheme.muted }
        if ms >= 3000 { return LogXTheme.err }
        if ms >= 800 { return LogXTheme.warn }
        return LogXTheme.ok
    }

    private var timeLabel: String {
        guard let ts = log.ts else { return "—" }
        let date = Date(timeIntervalSince1970: ts > 10_000_000_000 ? ts / 1000 : ts)
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private var app: String {
        log.appShortLabel
    }
}
