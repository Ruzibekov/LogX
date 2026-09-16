import SwiftUI
import LogXCore

/// Ro'yxat ustidagi kechikish chizig'i: har ustun — bitta so'rov, balandligi logarifmik.
/// Sekin so'rovni ro'yxatni varaqlamasdan topish uchun; ustun bosilsa o'sha so'rov tanlanadi.
struct LatencyTimelineView: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        let logs = Array(store.visibleLogs.prefix(LatencySummary.defaultLimit))
        if logs.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                header(count: logs.count)
                GeometryReader { geo in
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(LatencySummary.bars(logs)) { bar in
                            barView(bar, maxHeight: geo.size.height)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(height: 44)
            }
            .padding(.horizontal, 14)
            .padding(.top, 9)
            .padding(.bottom, 8)
            .background(LogXTheme.well)
            .overlay(alignment: .bottom) { Rectangle().fill(LogXTheme.line).frame(height: 1) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Kechikish chizig'i, \(logs.count) so'rov")
        }
    }

    private func header(count: Int) -> some View {
        HStack(spacing: 8) {
            Text("Kechikish oqimi · oxirgi \(count) so'rov")
                .font(LogXType.ui(LogXType.caption, .semibold))
                .tracking(0.4)
                .foregroundStyle(LogXTheme.muted)
            Spacer(minLength: 4)
            if let p95 = LatencySummary.p95Label(store.visibleLogs) {
                Text(p95)
                    .font(LogXType.mono(LogXType.caption))
                    .foregroundStyle(LogXTheme.muted)
            }
        }
    }

    private func barView(_ bar: LatencyBar, maxHeight: CGFloat) -> some View {
        let selected = store.selectedKey == bar.key
        return RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(color(bar, selected: selected))
            .frame(width: 4, height: max(3, maxHeight * bar.ratio))
            .contentShape(Rectangle())
            .onTapGesture { store.selectKey(bar.key) }
            .help(tooltip(bar))
    }

    private func color(_ bar: LatencyBar, selected: Bool) -> Color {
        if selected { return LogXTheme.accent }
        switch bar.statusClass {
        case .err5xx, .net: return LogXTheme.err
        case .err4xx: return LogXTheme.warn
        default: return LogXTheme.barTrack
        }
    }

    private func tooltip(_ bar: LatencyBar) -> String {
        guard let ms = bar.durationMs else { return "o'lchanmagan" }
        return ms >= 1000 ? String(format: "%.2f s", ms / 1000) : "\(Int(ms)) ms"
    }
}
