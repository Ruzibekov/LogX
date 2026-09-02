import SwiftUI
import LogXCore

struct RequestLiveBar: View {
    @EnvironmentObject private var store: LogStore
    var now: Date

    var body: some View {
        HStack(spacing: 8) {
            ConnectionDot(tint: tint, pulsing: store.connection == .live)
            Text(store.connection.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(summary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LogXTheme.muted2)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                ShortcutGlyph(parts: [.symbol("chevron.up.chevron.down")]).help("↑↓ — so'rovlar bo'ylab yurish")
                ShortcutGlyph(parts: [.symbol("command"), .letter("E")]).help("⌘E — keyingi xato, ⇧⌘E — oldingi")
                ShortcutGlyph(parts: [.symbol("command"), .letter("F")]).help("⌘F — so'rovlarni qidirish, ↓ ro'yxatga o'tadi")
                ShortcutGlyph(parts: [.symbol("command"), .symbol("return")]).help("⌘⏎ — tanlangan so'rovni qayta yuborish")
                ShortcutGlyph(parts: [.symbol("command"), .letter("D")]).help("⌘D — A deb belgilash, ⇧⌘D — A bilan solishtirish, ⌥⌘D — oldingi bir xil so'rov bilan")
                ShortcutGlyph(parts: [.symbol("command"), .letter("P")]).help("⌘P — pauza / davom")
                ShortcutGlyph(parts: [.symbol("command"), .symbol("shift"), .letter("C")]).help("⌘⇧C — cURL nusxalash")
                ShortcutGlyph(parts: [.symbol("command"), .letter("K")]).help("⌘K — tozalash, ⌥⌘K — bekor qilish")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(LogXTheme.panel)
        .overlay(Divider().overlay(LogXTheme.divider), alignment: .top)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.connection)
    }

    private var summary: String {
        var parts: [String] = []
        if store.visibleLogs.count != store.allLogs.count {
            parts.append("\(store.visibleLogs.count) ko'rinadi")
        }
        parts.append("\(store.allLogs.count) so'rov")
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
