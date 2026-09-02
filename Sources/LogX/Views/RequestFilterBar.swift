import SwiftUI
import LogXCore

struct RequestFilterBar: View {
    @EnvironmentObject private var store: LogStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            searchField
            HStack(spacing: 8) {
                statusSegment
                Spacer(minLength: 8)
                if store.hasActiveFilter {
                    clearButton
                }
                countBadge
            }
            HStack(spacing: 8) {
                methodSegment
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

    /// Ro'yxat qidiruvi: host, URL, sarlavha, tana. ⌘F fokus, Esc tozalaydi.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(searchFocused ? LogXTheme.accentLight : LogXTheme.muted2)
            TextField("Host, URL, sarlavha, tana (⌘F)", text: Binding(
                get: { store.query },
                set: { store.applyQuery($0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(LogXTheme.text)
            .focused($searchFocused)
            .accessibilityLabel("So'rovlarni qidirish")
            .onExitCommand {
                if store.query.isEmpty {
                    searchFocused = false
                } else {
                    store.applyQuery("")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: LogXNotice.focusListSearch)) { _ in
                searchFocused = true
            }
            if !store.query.isEmpty {
                Button {
                    store.applyQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(LogXTheme.muted2)
                }
                .buttonStyle(.plain)
                .help("Qidiruvni tozalash (Esc)")
                .accessibilityLabel("Qidiruvni tozalash")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LogXTheme.well)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(searchFocused ? LogXTheme.focusRing : LogXTheme.line, lineWidth: 1)
                )
        )
    }

    private var statusSegment: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
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
            }
            .fixedSize(horizontal: true, vertical: true)
            .padding(2)
            .background(segmentWell)
        }
        .frame(minHeight: 26)
    }

    private var methodSegment: some View {
        HStack(spacing: 1) {
            ForEach(["ALL", "GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { method in
                methodButton(method)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .padding(2)
        .background(segmentWell)
    }

    private var segmentWell: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LogXTheme.well)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(LogXTheme.line, lineWidth: 1)
            )
    }

    private var clearButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                store.clearFilters()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 10, weight: .bold))
                Text("Tozalash")
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(LogXTheme.accentLight)
            .lineLimit(1)
            .fixedSize()
        }
        .buttonStyle(LogXPressStyle())
        .help("Barcha filtrlarni tozalash")
    }

    private var countBadge: some View {
        Text("\(store.visibleLogs.count)")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(LogXTheme.muted)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(LogXTheme.well))
            .overlay(Capsule().stroke(LogXTheme.line, lineWidth: 1))
            .fixedSize()
            .help("Ko'rinayotgan so'rovlar")
    }

    private func methodButton(_ method: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                store.selectMethod(method)
            }
        } label: {
            Text(method == "ALL" ? "Hammasi" : method)
                .font(.system(size: 10, weight: store.selectedMethod == method ? .bold : .medium, design: .monospaced))
                .foregroundStyle(store.selectedMethod == method ? LogXTheme.text : LogXTheme.muted2)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4.5).fill(store.selectedMethod == method ? LogXTheme.chipOn : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 4.5).stroke(store.selectedMethod == method ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1))
                .fixedSize()
        }
        .buttonStyle(LogXPressStyle())
    }

    private var noiseToggle: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                store.toggleHideNoise()
            }
        } label: {
            Text(store.hideNoise && store.noiseHiddenCount > 0 ? "Shovqin (\(store.noiseHiddenCount))" : "Shovqin")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(store.hideNoise ? LogXTheme.accentLight : LogXTheme.muted)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(store.hideNoise ? LogXTheme.chipOn : Color.clear))
                .overlay(Capsule().stroke(store.hideNoise ? LogXTheme.chipOnEdge : LogXTheme.line, lineWidth: 1))
                .fixedSize()
        }
        .buttonStyle(LogXPressStyle())
        .help(store.hideNoise ? "Analytics, health, ping va rasm so'rovlari yashirilgan — bosib ko'rsating (⌥⌘N)" : "Analytics, health, ping va rasm so'rovlarini yashirish (⌥⌘N)")
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
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(store.slowOnly ? LogXTheme.warn.opacity(0.18) : Color.clear))
                .overlay(Capsule().stroke(store.slowOnly ? LogXTheme.warn.opacity(0.5) : LogXTheme.line, lineWidth: 1))
                .fixedSize()
        }
        .buttonStyle(LogXPressStyle())
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
                .background(Capsule().fill(active ? LogXTheme.chipOn : Color.clear))
                .overlay(Capsule().stroke(active ? LogXTheme.chipOnEdge : LogXTheme.line, lineWidth: 1))
        }
        .buttonStyle(LogXPressStyle())
        .help(host)
    }

    private var errorPill: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                store.toggleErrorsOnly()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8.5, weight: .bold))
                Text("\(store.errorCount)")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            }
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4.5).fill(store.errorsOnly ? LogXTheme.err.opacity(0.14) : (store.errorCount > 0 ? LogXTheme.err.opacity(0.08) : Color.clear)))
            .overlay(RoundedRectangle(cornerRadius: 4.5).stroke(store.errorsOnly ? LogXTheme.err.opacity(0.45) : Color.clear, lineWidth: 1))
            .foregroundStyle(store.errorsOnly || store.errorCount > 0 ? LogXTheme.err : LogXTheme.muted)
            .fixedSize()
        }
        .buttonStyle(LogXPressStyle())
        .help("Faqat xatolar: 4xx + 5xx + NET")
    }

    private func segment(_ title: String, count: Int, color: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10.5, weight: active ? .semibold : .medium))
                    .lineLimit(1)
                Text("\(count)")
                    .font(.system(size: 10, weight: active ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(active ? color : LogXTheme.muted2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4.5).fill(active ? (color == LogXTheme.text ? LogXTheme.chipOn : color.opacity(0.12)) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 4.5).stroke(active ? (color == LogXTheme.text ? LogXTheme.chipOnEdge : color.opacity(0.35)) : Color.clear, lineWidth: 1))
            .foregroundStyle(active ? LogXTheme.text : LogXTheme.muted)
            .fixedSize()
        }
        .buttonStyle(LogXPressStyle())
    }
}
