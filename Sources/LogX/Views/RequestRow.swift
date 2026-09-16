import SwiftUI
import LogXCore

struct RequestRow: View {
    @EnvironmentObject private var store: LogStore
    var log: NetworkLog
    var selected: Bool
    var now: Date
    var showAppColumn: Bool = true
    var showTimeColumn: Bool = true
    @State private var hovered = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            statusPill
            VStack(alignment: .leading, spacing: 3) {
                metaLine
                pathLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            metrics
            favoriteButton.frame(width: 18, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(rowBackground)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(LogXTheme.divider).frame(height: 1)
        }
        .onTapGesture { store.selectLog(log) }
        .onHover { hovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(log.method) \(log.responseCode.map(String.init) ?? "NET") \(store.displayPath(log))")
    }

    private var rowBackground: Color {
        if selected { return LogXTheme.selection }
        return hovered ? LogXTheme.panel2 : Color.clear
    }

    private var statusPill: some View {
        Text(log.responseCode.map(String.init) ?? "NET")
            .font(LogXType.mono(11, .bold))
            .foregroundStyle(LogXTheme.status(log.statusClass))
            .frame(width: 42, height: 21)
            .background(LogXTheme.statusTint(log.statusClass), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .help(log.statusDescription)
            .accessibilityLabel("Status \(log.responseCode.map(String.init) ?? "tarmoq xatosi")")
    }

    private var metaLine: some View {
        HStack(spacing: 7) {
            Text(log.method)
                .font(LogXType.mono(LogXType.caption, .bold))
                .tracking(0.6)
                .foregroundStyle(selected ? LogXTheme.accent : LogXTheme.muted)
                .fixedSize()

            if !log.hostLabel.isEmpty, store.hasMultipleHosts {
                Text(log.hostLabel)
                    .font(LogXType.mono(LogXType.caption))
                    .foregroundStyle(LogXTheme.muted2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(-1)
            }

            if showAppColumn, store.selectedAppId == "all", !log.appShortLabel.isEmpty {
                badge(log.appShortLabel, tint: LogXTheme.accent)
                    .help(log.appLabel)
            }

            let repeats = store.repeatCount(for: log)
            if repeats > 1 {
                Button { store.filterEndpoint(log) } label: {
                    badge("×\(repeats)", tint: LogXTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Shu endpoint \(repeats) marta — bosilsa faqat shular qoladi")
                .accessibilityLabel("Shu endpointni filtrlash")
            }

            if store.diffAnchorKey == log.key {
                badge("A", tint: LogXTheme.err)
                    .help("Solishtirish uchun belgilangan — boshqa so'rovda ⇧⌘D")
            }

            if Replay.isReplay(log) {
                badge("REPLAY", tint: LogXTheme.replay)
                    .help("Mac'dan qayta yuborilgan so'rov")
            }

            if RelativeTime.isFresh(ts: log.ts, now: now) {
                badge("YANGI", tint: LogXTheme.ok)
            }

            Spacer(minLength: 0)
        }
    }

    private var pathLine: some View {
        HStack(spacing: 6) {
            Text(URLHighlighter.attributed(store.displayPath(log), baseFontSize: LogXType.body, selected: selected))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(store.shareableURL(log))

            if hovered || copied {
                Button {
                    store.copy(store.shareableURL(log), what: "URL")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(copied ? LogXTheme.ok : LogXTheme.text2)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(copied ? "Nusxalandi!" : "URL nusxalash")
                .accessibilityLabel("URL nusxalash")
            }

            Spacer(minLength: 0)
        }
    }

    private var metrics: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(log.formattedDuration)
                .font(LogXType.mono(LogXType.meta, selected ? .semibold : .regular))
                .foregroundStyle(durationColor)
            if showTimeColumn {
                Text(RelativeTime.clock(ts: log.ts))
                    .font(LogXType.mono(LogXType.caption))
                    .foregroundStyle(LogXTheme.muted2)
                    .help(RelativeTime.label(ts: log.ts, now: now))
            }
        }
        .frame(width: 72, alignment: .trailing)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(LogXType.mono(9, .bold))
            .tracking(0.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder
    private var favoriteButton: some View {
        if hovered || store.isFavorite(log.key) {
            Button {
                store.toggleFavorite(log.key)
            } label: {
                Image(systemName: store.isFavorite(log.key) ? "star.fill" : "star")
                    .font(.system(size: 10.5))
                    .foregroundStyle(store.isFavorite(log.key) ? LogXTheme.warn : LogXTheme.text2)
            }
            .buttonStyle(.plain)
            .help("Sevimli")
            .accessibilityLabel(store.isFavorite(log.key) ? "Sevimlilardan o'chirish" : "Sevimlilarga qo'shish")
        }
    }

    private var durationColor: Color {
        guard let ms = log.durationMs else { return LogXTheme.muted2 }
        if ms >= LogNoise.verySlowThresholdMs { return LogXTheme.err }
        if ms >= LogNoise.slowThresholdMs { return LogXTheme.warn }
        return LogXTheme.text2
    }
}
