import SwiftUI
import LogXCore

struct RequestFilterBar: View {
    @EnvironmentObject private var store: LogStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                searchField
                livePill
                sortMenu
                clearLogsButton
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    statusChip("Hammasi", count: store.statusCount(.all), tint: LogXTheme.accent, active: !store.errorsOnly && store.status == .all) {
                        store.selectStatus(.all)
                    }
                    ForEach([StatusClass.ok2xx, .redirect3xx, .err4xx, .err5xx, .net], id: \.self) { item in
                        statusChip(item.title, count: store.statusCount(item), tint: LogXTheme.status(item), active: !store.errorsOnly && store.status == item) {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(LogXTheme.panel)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: store.status)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: store.selectedMethod)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.hasActiveFilter)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: store.hideNoise)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: store.slowOnly)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: store.selectedHost)
    }

    private var divider: some View {
        Rectangle()
            .fill(LogXTheme.line)
            .frame(width: 1, height: 16)
            .padding(.horizontal, 2)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(searchFocused ? LogXTheme.accent : LogXTheme.muted2)
            TextField("Host, URL, sarlavha, tana", text: Binding(get: { store.query }, set: { store.applyQuery($0) }))
                .textFieldStyle(.plain)
                .font(LogXType.mono(LogXType.body))
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
                    .font(LogXType.mono(LogXType.caption, .semibold))
                    .foregroundStyle(LogXTheme.muted2)
            } else {
                Button { store.applyQuery("") } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(LogXTheme.muted2)
                }
                .buttonStyle(.plain)
                .help("Qidiruvni tozalash (Esc)")
                .accessibilityLabel("Qidiruvni tozalash")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(LogXTheme.well)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(searchFocused ? LogXTheme.focusRing : LogXTheme.line, lineWidth: 1)
                )
        )
    }

    private var livePill: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.togglePause() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: store.isPaused ? "pause.fill" : "bolt.fill")
                    .font(.system(size: 9.5, weight: .bold))
                Text(store.isPaused ? "PAUZA" : "JONLI")
                    .font(LogXType.ui(LogXType.caption, .bold))
                    .tracking(0.7)
            }
            .foregroundStyle(store.isPaused ? LogXTheme.warn : LogXTheme.accent)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(store.isPaused ? LogXTheme.warn.opacity(0.14) : LogXTheme.chipOn)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(store.isPaused ? LogXTheme.warn.opacity(0.45) : LogXTheme.chipOnEdge, lineWidth: 1)
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
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(store.sortField == .time && store.sortOrder == .descending ? LogXTheme.muted : LogXTheme.accent)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(LogXTheme.well))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 30, height: 30)
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
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.clearLogs() }
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(LogXTheme.muted)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(LogXTheme.well))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
        }
        .buttonStyle(LogXPressStyle())
        .disabled(store.logCount == 0)
        .keyboardShortcut("k", modifiers: .command)
        .help("Ro'yxatni tozalash (⌘K)")
        .accessibilityLabel("Ro'yxatni tozalash")
    }

    private var clearButton: some View {
        Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { store.clearFilters() } } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 10, weight: .bold))
                Text("Tozalash")
                    .font(LogXType.ui(LogXType.caption, .semibold))
            }
            .foregroundStyle(LogXTheme.accent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(height: 26)
        }
        .buttonStyle(LogXPressStyle())
        .help("Barcha filtrlarni tozalash")
    }

    private func statusChip(_ title: String, count: Int, tint: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) { action() } } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(LogXType.ui(LogXType.meta, active ? .semibold : .medium))
                Text("\(count)")
                    .font(LogXType.mono(LogXType.caption, .semibold))
                    .foregroundStyle(active ? tint : LogXTheme.muted2)
            }
            .foregroundStyle(active ? LogXTheme.text : LogXTheme.muted)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? tint.opacity(0.14) : LogXTheme.panel2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(active ? tint.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(LogXPressStyle())
    }

    private func methodChip(_ method: String) -> some View {
        let active = store.selectedMethod == method
        return Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.selectMethod(active ? "ALL" : method) } } label: {
            Text(method)
                .font(LogXType.mono(LogXType.caption, active ? .bold : .medium))
                .foregroundStyle(active ? LogXTheme.text : LogXTheme.muted)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(active ? LogXTheme.chipOn : LogXTheme.panel2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(active ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(LogXPressStyle())
        .help("\(method) so'rovlari")
    }

    private var noiseToggle: some View {
        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.toggleHideNoise() } } label: {
            chipLabel(
                store.hideNoise && store.noiseHiddenCount > 0 ? "Shovqin \(store.noiseHiddenCount)" : "Shovqin",
                active: store.hideNoise,
                tint: LogXTheme.accent
            )
        }
        .buttonStyle(LogXPressStyle())
        .help(store.hideNoise ? "Analytics, health, ping va rasm so'rovlari yashirilgan — bosib ko'rsating (⌥⌘N)" : "Analytics, health, ping va rasm so'rovlarini yashirish (⌥⌘N)")
    }

    private var slowPill: some View {
        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.toggleSlowOnly() } } label: {
            chipLabel("Sekin", active: store.slowOnly, tint: LogXTheme.warn)
        }
        .buttonStyle(LogXPressStyle())
        .help("Faqat ≥ 800 ms")
    }

    private func hostChip(_ host: String) -> some View {
        let active = store.selectedHost == host
        return Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.selectHost(host) } } label: {
            Text(host)
                .font(LogXType.mono(LogXType.caption, active ? .semibold : .regular))
                .foregroundStyle(active ? LogXTheme.text : LogXTheme.muted)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(active ? LogXTheme.chipOn : LogXTheme.panel2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(active ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(LogXPressStyle())
        .help(host)
    }

    private var errorPill: some View {
        Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) { store.toggleErrorsOnly() } } label: {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8.5, weight: .bold))
                Text("\(store.errorCount)")
                    .font(LogXType.mono(LogXType.caption, .bold))
            }
            .foregroundStyle(store.errorsOnly || store.errorCount > 0 ? LogXTheme.err : LogXTheme.muted2)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(store.errorsOnly ? LogXTheme.err.opacity(0.16) : LogXTheme.panel2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(store.errorsOnly ? LogXTheme.err.opacity(0.42) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(LogXPressStyle())
        .help("Faqat xatolar: 4xx + 5xx + NET")
    }

    private func chipLabel(_ title: String, active: Bool, tint: Color) -> some View {
        Text(title)
            .font(LogXType.ui(LogXType.meta, active ? .semibold : .medium))
            .foregroundStyle(active ? tint : LogXTheme.muted)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? tint.opacity(0.14) : LogXTheme.panel2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(active ? tint.opacity(0.4) : Color.clear, lineWidth: 1)
            )
    }
}
