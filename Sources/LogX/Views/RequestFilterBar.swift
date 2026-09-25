import SwiftUI
import LogXCore

struct RequestFilterBar: View {
    @EnvironmentObject private var store: LogStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                searchField
                sortMenu
                clearLogsButton
            }
            HStack(spacing: 6) {
                livePill
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        statusChip("Hammasi", count: store.statusCount(.all), active: !store.errorsOnly && store.status == .all) {
                            store.selectStatus(.all)
                        }
                        ForEach([StatusClass.ok2xx, .redirect3xx, .err4xx, .err5xx, .net], id: \.self) { item in
                            statusChip(item.title, count: store.statusCount(item), active: !store.errorsOnly && store.status == item) {
                                store.selectStatus(item)
                            }
                        }
                        errorPill
                        divider
                        ForEach(["GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { method in
                            methodChip(method)
                        }
                        divider
                        noiseToggle
                        slowPill
                        ForEach(store.uniqueHosts.count > 1 ? store.uniqueHosts : [], id: \.self) { host in
                            hostChip(host)
                        }
                        if store.hasActiveFilter { clearButton }
                    }
                    .padding(.trailing, 14)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(LogXTheme.bg)
        .animation(LogXMotion.settle, value: store.status)
        .animation(LogXMotion.settle, value: store.selectedMethod)
        .animation(LogXMotion.settle, value: store.hasActiveFilter)
        .animation(LogXMotion.snappy, value: store.hideNoise)
        .animation(LogXMotion.snappy, value: store.slowOnly)
        .animation(LogXMotion.snappy, value: store.selectedHost)
    }

    private var divider: some View {
        Rectangle()
            .fill(LogXTheme.line)
            .frame(width: 1, height: 14)
            .padding(.horizontal, 2)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(searchFocused ? LogXTheme.accent : LogXTheme.muted)
            TextField("Host, URL, sarlavha, tana", text: Binding(get: { store.query }, set: { store.applyQuery($0) }))
                .textFieldStyle(.plain)
                .font(LogXType.ui(LogXType.body))
                .foregroundStyle(LogXTheme.text)
                .focused($searchFocused)
                .accessibilityLabel("So'rovlarni qidirish")
                .onExitCommand {
                    if store.query.isEmpty { searchFocused = false } else { store.applyQuery("") }
                }
                .onReceive(NotificationCenter.default.publisher(for: LogXNotice.focusListSearch)) { _ in searchFocused = true }
                .onKeyPress(.downArrow) {
                    searchFocused = false
                    NotificationCenter.default.post(name: LogXNotice.focusList, object: nil)
                    return .handled
                }
            if store.query.isEmpty {
                Text("⌘F")
                    .font(LogXType.mono(LogXType.caption))
                    .foregroundStyle(LogXTheme.muted)
            } else {
                Button { store.applyQuery("") } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(LogXTheme.muted)
                }
                .buttonStyle(.plain)
                .help("Qidiruvni tozalash (Esc)")
                .accessibilityLabel("Qidiruvni tozalash")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous).fill(LogXTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                        .stroke(searchFocused ? LogXTheme.focusRing : LogXTheme.line, lineWidth: 1)
                )
        )
    }

    private var livePill: some View {
        let tint = store.isPaused ? LogXTheme.warn : LogXTheme.ok
        return Button {
            LogXMotion.perform(LogXMotion.snappy) { store.togglePause() }
        } label: {
            HStack(spacing: 5) {
                if store.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 7.5, weight: .bold))
                } else {
                    LiveDot(tint: tint, pulsing: store.connection == .live, size: 6)
                }
                Text(store.isPaused ? "PAUZA" : "JONLI")
                    .font(LogXType.mono(10.5, .semibold))
            }
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: LogXRadius.chip, style: .continuous)
                    .fill(store.isPaused ? LogXTheme.warn.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LogXRadius.chip, style: .continuous)
                    .stroke(tint, lineWidth: 1)
            )
        }
        .buttonStyle(LogXPressStyle())
        .keyboardShortcut("p", modifiers: .command)
        .help(store.isPaused ? "Davom ettirish (⌘P)" : "Pauza — yangi so'rovlar buferda to'planadi (⌘P)")
        .accessibilityLabel(store.isPaused ? "Davom ettirish" : "Pauza")
    }

    private var sortMenu: some View {
        Menu {
            sortItem("Vaqt", field: .time)
            sortItem("Davomiylik", field: .duration)
            sortItem("Kod", field: .status)
            sortItem("Metod", field: .method)
            sortItem("Manzil", field: .path)
        } label: {
            squareIcon("arrow.up.arrow.down", tint: store.sortField == .time && store.sortOrder == .descending ? LogXTheme.muted : LogXTheme.accent)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 32, height: 32)
        .help("Saralash tartibi")
        .accessibilityLabel("Saralash")
    }

    private func sortItem(_ title: String, field: LogSortField) -> some View {
        Button {
            store.toggleSort(field)
        } label: {
            if store.sortField == field {
                Label("\(title) \(store.sortOrder == .ascending ? "↑" : "↓")", systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var clearLogsButton: some View {
        Button {
            LogXMotion.perform(LogXMotion.snappy) { store.clearLogs() }
        } label: {
            squareIcon("trash", tint: LogXTheme.muted)
        }
        .buttonStyle(LogXPressStyle())
        .disabled(store.logCount == 0)
        .keyboardShortcut("k", modifiers: .command)
        .help("Ro'yxatni tozalash (⌘K)")
        .accessibilityLabel("Ro'yxatni tozalash")
    }

    private func squareIcon(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous).fill(LogXTheme.panel))
            .overlay(RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
    }

    private var clearButton: some View {
        Button { LogXMotion.perform(LogXMotion.settle) { store.clearFilters() } } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 9.5, weight: .bold))
                Text("Tozalash")
                    .font(LogXType.mono(10.5, .medium))
            }
            .foregroundStyle(LogXTheme.accent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .frame(height: 24)
        }
        .buttonStyle(LogXPressStyle())
        .help("Barcha filtrlarni tozalash")
    }

    private func statusChip(_ title: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button { LogXMotion.perform(LogXMotion.settle) { action() } } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(LogXType.mono(10.5, active ? .semibold : .medium))
                Text("\(count)")
                    .font(LogXType.mono(10.5, active ? .semibold : .regular))
                    .foregroundStyle(active ? LogXTheme.accent : (count > 0 ? LogXTheme.text2 : LogXTheme.muted))
            }
            .modifier(FilterChipFrame(active: active))
        }
        .buttonStyle(LogXPressStyle())
    }

    private func methodChip(_ method: String) -> some View {
        let active = store.selectedMethod == method
        let tint = LogXTheme.methodColor(method)
        return Button { LogXMotion.perform(LogXMotion.snappy) { store.selectMethod(active ? "ALL" : method) } } label: {
            Text(method)
                .font(LogXType.mono(10.5, active ? .bold : .semibold))
                .modifier(FilterChipFrame(active: active, tint: tint, idleInk: tint))
        }
        .buttonStyle(LogXPressStyle())
        .help("\(method) so'rovlari")
    }

    private var noiseToggle: some View {
        Button { LogXMotion.perform(LogXMotion.snappy) { store.toggleHideNoise() } } label: {
            chipLabel(
                store.hideNoise && store.noiseHiddenCount > 0 ? "Shovqin \(store.noiseHiddenCount)" : "Shovqin",
                active: store.hideNoise
            )
        }
        .buttonStyle(LogXPressStyle())
        .help(store.hideNoise ? "Analytics, health, ping va rasm so'rovlari yashirilgan — bosib ko'rsating (⌥⌘N)" : "Analytics, health, ping va rasm so'rovlarini yashirish (⌥⌘N)")
    }

    private var slowPill: some View {
        Button { LogXMotion.perform(LogXMotion.snappy) { store.toggleSlowOnly() } } label: {
            chipLabel("Sekin", active: store.slowOnly, tint: LogXTheme.warn)
        }
        .buttonStyle(LogXPressStyle())
        .help("Faqat ≥ 800 ms")
    }

    private func hostChip(_ host: String) -> some View {
        let active = store.selectedHost == host
        return Button { LogXMotion.perform(LogXMotion.snappy) { store.selectHost(host) } } label: {
            Text(host)
                .font(LogXType.mono(10.5, active ? .semibold : .regular))
                .modifier(FilterChipFrame(active: active))
        }
        .buttonStyle(LogXPressStyle())
        .help(host)
    }

    private var errorPill: some View {
        Button { LogXMotion.perform(LogXMotion.settle) { store.toggleErrorsOnly() } } label: {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8, weight: .bold))
                Text("\(store.errorCount)")
                    .font(LogXType.mono(10.5, .semibold))
            }
            .modifier(FilterChipFrame(active: store.errorsOnly, tint: LogXTheme.err, idleInk: store.errorCount > 0 ? LogXTheme.err : LogXTheme.muted))
        }
        .buttonStyle(LogXPressStyle())
        .help("Faqat xatolar: 4xx + 5xx + NET")
    }

    private func chipLabel(_ title: String, active: Bool, tint: Color = LogXTheme.accent) -> some View {
        Text(title)
            .font(LogXType.mono(10.5, active ? .semibold : .medium))
            .modifier(FilterChipFrame(active: active, tint: tint))
    }
}

struct FilterChipFrame: ViewModifier {
    var active: Bool
    var tint: Color = LogXTheme.accent
    var idleInk: Color = LogXTheme.text2

    private var activeFill: Color {
        tint == LogXTheme.accent ? LogXTheme.chipOn : tint.opacity(0.12)
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: LogXRadius.chip, style: .continuous)
        return content
            .foregroundStyle(active ? tint : idleInk)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(shape.fill(active ? activeFill : Color.clear))
            .overlay(shape.stroke(active ? tint.opacity(0.45) : LogXTheme.line, lineWidth: 1))
    }
}
