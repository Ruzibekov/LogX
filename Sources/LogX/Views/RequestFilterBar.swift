import SwiftUI
import LogXCore

struct RequestFilterBar: View {
    @EnvironmentObject private var store: LogStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            searchField
            HStack(spacing: 8) {
                statusSegment.layoutPriority(0)
                Spacer(minLength: 4)
                if store.hasActiveFilter { clearButton.layoutPriority(1) }
                countBadge.layoutPriority(1)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    methodSegment
                    noiseToggle
                    slowPill
                    if store.uniqueHosts.count > 1 {
                        HStack(spacing: 5) {
                            ForEach(store.uniqueHosts, id: \.self) { host in hostChip(host) }
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
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

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .medium))
                .foregroundStyle(searchFocused ? LogXTheme.accentLight : LogXTheme.muted2)
            TextField("Host, URL, sarlavha, tana (⌘F)", text: Binding(get: { store.query }, set: { store.applyQuery($0) }))
                .textFieldStyle(.plain).font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(LogXTheme.text).focused($searchFocused).accessibilityLabel("So'rovlarni qidirish")
                .onExitCommand {
                    if store.query.isEmpty { searchFocused = false } else { store.applyQuery("") }
                }
                .onReceive(NotificationCenter.default.publisher(for: LogXNotice.focusListSearch)) { _ in searchFocused = true }
                .onKeyPress(.downArrow) {
                    searchFocused = false
                    NotificationCenter.default.post(name: LogXNotice.focusList, object: nil)
                    return .handled
                }
            if !store.query.isEmpty {
                Button { store.applyQuery("") } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(LogXTheme.muted2)
                }
                .buttonStyle(.plain).help("Qidiruvni tozalash (Esc)").accessibilityLabel("Qidiruvni tozalash")
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LogXTheme.well)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(searchFocused ? LogXTheme.focusRing : LogXTheme.line.opacity(0.8), lineWidth: 1))
        )
    }

    private var statusSegment: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                segment("Barchasi", count: store.statusCount(.all), color: LogXTheme.text, active: !store.errorsOnly && store.status == .all) {
                    store.selectStatus(.all)
                }
                ForEach([StatusClass.ok2xx, .redirect3xx, .err4xx, .err5xx, .net], id: \.self) { item in
                    segment(item.title, count: store.statusCount(item), color: LogXTheme.status(item), active: !store.errorsOnly && store.status == item) {
                        store.selectStatus(item)
                    }
                }
                errorPill
            }
            .fixedSize(horizontal: true, vertical: true).padding(2).background(segmentWell)
        }
        .frame(minHeight: 26)
    }

    private var methodSegment: some View {
        HStack(spacing: 1) {
            ForEach(["ALL", "GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { method in
                methodButton(method)
            }
        }
        .fixedSize(horizontal: true, vertical: true).padding(2).background(segmentWell)
    }

    private var segmentWell: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(LogXTheme.well)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(LogXTheme.line.opacity(0.7), lineWidth: 1))
    }

    private var clearButton: some View {
        Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { store.clearFilters() } } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle").font(.system(size: 10, weight: .bold))
                Text("Tozalash").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(LogXTheme.accentLight).lineLimit(1).fixedSize()
        }
        .buttonStyle(LogXPressStyle()).help("Barcha filtrlarni tozalash")
    }

    private var countBadge: some View {
        Text("\(store.visibleLogs.count)")
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced)).foregroundStyle(LogXTheme.muted2)
            .lineLimit(1).padding(.horizontal, 6).padding(.vertical, 2.5)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(LogXTheme.well)).fixedSize().help("Ko'rinayotgan so'rovlar")
    }

    private func methodButton(_ method: String) -> some View {
        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.selectMethod(method) } } label: {
            Text(method == "ALL" ? "Hammasi" : method)
                .font(.system(size: 10, weight: store.selectedMethod == method ? .semibold : .medium, design: .monospaced))
                .foregroundStyle(store.selectedMethod == method ? LogXTheme.text : LogXTheme.muted2).lineLimit(1)
                .padding(.horizontal, 6).padding(.vertical, 2.5)
                .background(RoundedRectangle(cornerRadius: 3.5).fill(store.selectedMethod == method ? LogXTheme.chipOn : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(store.selectedMethod == method ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1)).fixedSize()
        }
        .buttonStyle(LogXPressStyle())
    }

    private var noiseToggle: some View {
        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.toggleHideNoise() } } label: {
            Text(store.hideNoise && store.noiseHiddenCount > 0 ? "Shovqin (\(store.noiseHiddenCount))" : "Shovqin")
                .font(.system(size: 10, weight: store.hideNoise ? .semibold : .medium))
                .foregroundStyle(store.hideNoise ? LogXTheme.accentLight : LogXTheme.muted2).lineLimit(1)
                .padding(.horizontal, 7).padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(store.hideNoise ? LogXTheme.chipOn : LogXTheme.well.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(store.hideNoise ? LogXTheme.chipOnEdge : LogXTheme.line.opacity(0.5), lineWidth: 1)).fixedSize()
        }
        .buttonStyle(LogXPressStyle())
        .help(store.hideNoise ? "Analytics, health, ping va rasm so'rovlari yashirilgan — bosib ko'rsating (⌥⌘N)" : "Analytics, health, ping va rasm so'rovlarini yashirish (⌥⌘N)")
    }

    private var slowPill: some View {
        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.toggleSlowOnly() } } label: {
            Text("Sekin")
                .font(.system(size: 10, weight: store.slowOnly ? .semibold : .medium))
                .foregroundStyle(store.slowOnly ? LogXTheme.warn : LogXTheme.muted2).lineLimit(1)
                .padding(.horizontal, 7).padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(store.slowOnly ? LogXTheme.warn.opacity(0.16) : LogXTheme.well.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(store.slowOnly ? LogXTheme.warn.opacity(0.45) : LogXTheme.line.opacity(0.5), lineWidth: 1)).fixedSize()
        }
        .buttonStyle(LogXPressStyle())
        .help("Faqat ≥ 800 ms")
    }

    private func hostChip(_ host: String) -> some View {
        let active = store.selectedHost == host
        return Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.selectHost(host) } } label: {
            Text(host)
                .font(.system(size: 10, weight: active ? .semibold : .medium, design: .monospaced))
                .foregroundStyle(active ? LogXTheme.text : LogXTheme.muted2).lineLimit(1)
                .padding(.horizontal, 7).padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(active ? LogXTheme.chipOn : LogXTheme.well.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(active ? LogXTheme.chipOnEdge : LogXTheme.line.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(LogXPressStyle()).help(host)
    }

    private var errorPill: some View {
        Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) { store.toggleErrorsOnly() } } label: {
            HStack(spacing: 3.5) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8, weight: .bold))
                Text("\(store.errorCount)").font(.system(size: 10, weight: store.errorsOnly ? .bold : .medium, design: .monospaced))
            }
            .lineLimit(1).padding(.horizontal, 5).padding(.vertical, 2.5)
            .background(RoundedRectangle(cornerRadius: 3.5).fill(store.errorsOnly ? LogXTheme.err.opacity(0.14) : (store.errorCount > 0 ? LogXTheme.err.opacity(0.08) : Color.clear)))
            .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(store.errorsOnly ? LogXTheme.err.opacity(0.4) : Color.clear, lineWidth: 1))
            .foregroundStyle(store.errorsOnly || store.errorCount > 0 ? LogXTheme.err : LogXTheme.muted2).fixedSize()
        }
        .buttonStyle(LogXPressStyle()).help("Faqat xatolar: 4xx + 5xx + NET")
    }

    private func segment(_ title: String, count: Int, color: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) { action() } } label: {
            HStack(spacing: 3.5) {
                Text(title).font(.system(size: 10, weight: active ? .semibold : .medium)).lineLimit(1)
                Text("\(count)").font(.system(size: 9.5, weight: active ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(active ? color : (count > 0 ? color.opacity(0.8) : LogXTheme.muted2)).lineLimit(1)
            }
            .padding(.horizontal, 5.5).padding(.vertical, 2.5)
            .background(RoundedRectangle(cornerRadius: 3.5).fill(active ? (color == LogXTheme.text ? LogXTheme.chipOn : color.opacity(0.12)) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(active ? (color == LogXTheme.text ? LogXTheme.chipOnEdge : color.opacity(0.28)) : Color.clear, lineWidth: 1))
            .foregroundStyle(active ? LogXTheme.text : LogXTheme.muted).fixedSize()
        }
        .buttonStyle(LogXPressStyle())
    }
}
