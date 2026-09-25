import SwiftUI
import LogXCore

struct RequestLiveBar: View {
    @EnvironmentObject private var store: LogStore
    var now: Date

    var body: some View {
        HStack(spacing: 8) {
            ConnectionDot(tint: tint, pulsing: store.connection == .live)
            Text(store.connection.title)
                .font(LogXType.mono(11, .medium))
                .foregroundStyle(tint)
                .fixedSize(horizontal: true, vertical: false)
            Text("·")
                .font(LogXType.mono(11))
                .foregroundStyle(LogXTheme.muted2)
            Text(summary)
                .font(LogXType.mono(11))
                .foregroundStyle(LogXTheme.muted)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            ViewThatFits(in: .horizontal) {
                hints
                shortcutGlyphs
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(minHeight: 28)
        .background(LogXTheme.chrome)
        .overlay(alignment: .top) { Rectangle().fill(LogXTheme.line).frame(height: 1) }
        .animation(LogXMotion.settle, value: store.connection)
    }

    private var hints: some View {
        HStack(spacing: 12) {
            hint([.symbol("command"), .symbol("return")], "qayta yuborish")
            hint([.symbol("command"), .letter("D")], "farq")
            hint([.symbol("command"), .letter("F")], "qidirish")
            hint([.symbol("command"), .letter("K")], "tozalash")
        }
    }

    private var shortcutGlyphs: some View {
        HStack(spacing: 6) {
            ShortcutGlyph(parts: [.symbol("command"), .symbol("return")]).help("⌘⏎ — tanlangan so'rovni qayta yuborish")
            ShortcutGlyph(parts: [.symbol("command"), .letter("D")]).help("⌘D — A deb belgilash, ⇧⌘D — A bilan solishtirish")
            ShortcutGlyph(parts: [.symbol("command"), .letter("F")]).help("⌘F — qidirish")
            ShortcutGlyph(parts: [.symbol("command"), .letter("K")]).help("⌘K — tozalash, ⌥⌘K — bekor qilish")
        }
    }

    private func hint(_ parts: [ShortcutGlyph.Part], _ label: String) -> some View {
        HStack(spacing: 5) {
            ShortcutGlyph(parts: parts)
            Text(label)
                .font(LogXType.mono(10.5))
                .foregroundStyle(LogXTheme.muted)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var summary: String {
        var parts: [String] = []
        parts.append(store.selectedScope.title)
        if store.visibleLogs.count != store.logCount {
            parts.append("\(store.visibleLogs.count) ko'rinadi")
        }
        parts.append("\(store.logCount) so'rov")
        if store.bodyBytesEstimate > 0 {
            parts.append(ByteSize.label(store.bodyBytesEstimate))
        }
        if store.isPaused, store.pendingWhilePausedCount > 0 {
            parts.append("\(store.pendingWhilePausedCount) buferda")
        }
        if store.isNearCapacity {
            parts.append("sig'im \(store.maxLogCapacity) — eskilari tushadi")
        }
        parts.append("oxirgisi \(RelativeTime.label(ts: store.lastActivityTs, now: now))")
        return parts.joined(separator: " · ")
    }

    private var tint: Color {
        switch store.connection {
        case .live: return LogXTheme.ok
        case .reconnecting, .paused, .connecting, .booting, .noDevice: return LogXTheme.warn
        case .serverDown: return LogXTheme.err
        }
    }
}
