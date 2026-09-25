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
    @State private var entered = true

    static let height: CGFloat = 54

    var body: some View {
        HStack(spacing: 12) {
            statusPill
            VStack(alignment: .leading, spacing: 4) {
                metaLine
                pathLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            metrics
            favoriteButton.frame(width: 16, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Self.height)
        .contentShape(Rectangle())
        .opacity(entered ? 1 : 0)
        .offset(y: entered ? 0 : -LogXMotion.rowInsertOffset)
        .onAppear(perform: enter)
        .onTapGesture { store.selectLog(log) }
        .onHover(perform: trackHover)
        .onDisappear { store.rowHover.release(log.key) }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(log.method) \(log.responseCode.map(String.init) ?? "NET") \(store.displayPath(log))")
    }

    private func enter() {
        guard RowEntrance.shouldAnimate(ts: log.ts, now: Date()), let animation = LogXMotion.rowInsert else { return }
        entered = false
        withAnimation(animation) { entered = true }
    }

    private func trackHover(_ inside: Bool) {
        hovered = inside
        store.rowHover.update(log.key, inside: inside)
    }

    private var statusPill: some View {
        Text(log.responseCode.map(String.init) ?? "NET")
            .font(LogXType.mono(11, .bold))
            .foregroundStyle(LogXTheme.status(log.statusClass))
            .lineLimit(1)
            .frame(width: 44, height: 22)
            .background(LogXTheme.statusTint(log.statusClass), in: RoundedRectangle(cornerRadius: LogXRadius.chip, style: .continuous))
            .help(log.statusDescription)
            .accessibilityLabel("Status \(log.responseCode.map(String.init) ?? "tarmoq xatosi")")
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            Text(log.method.uppercased())
                .font(LogXType.mono(LogXType.caption, .semibold))
                .tracking(0.6)
                .foregroundStyle(log.method.uppercased() == "DELETE" ? LogXTheme.err : LogXTheme.muted)
                .fixedSize()

            if !log.hostLabel.isEmpty, store.hasMultipleHosts {
                Text(log.hostLabel)
                    .font(LogXType.mono(LogXType.caption))
                    .foregroundStyle(LogXTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(-1)
            }

            if showAppColumn, store.selectedAppId == "all", !log.appShortLabel.isEmpty {
                badge(log.appShortLabel, tint: LogXTheme.text2)
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
            Text(URLStyle.attributed(store.displayPath(log), size: LogXType.body, weight: selected ? .semibold : .medium))
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
        VStack(alignment: .trailing, spacing: 4) {
            Text(log.formattedDuration)
                .font(LogXType.mono(LogXType.meta, selected ? .semibold : .medium))
                .foregroundStyle(durationColor)
                .lineLimit(1)
            if showTimeColumn {
                Text(RelativeTime.clock(ts: log.ts))
                    .font(LogXType.mono(10.5))
                    .foregroundStyle(LogXTheme.muted)
                    .lineLimit(1)
                    .help(RelativeTime.label(ts: log.ts, now: now))
            }
        }
        .frame(minWidth: 74, alignment: .trailing)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(LogXType.mono(9, .bold))
            .tracking(0.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
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
        switch SignalTrace.level(log.durationMs.map(Double.init)) {
        case .verySlow: return LogXTheme.err
        case .slow: return LogXTheme.warn
        case .normal: return LogXTheme.text2
        case .unmeasured: return LogXTheme.muted
        }
    }
}

enum RowEntrance {
    static let window: TimeInterval = 1.5

    static func shouldAnimate(ts: Double?, now: Date) -> Bool {
        guard let ts else { return false }
        let seconds = ts > 10_000_000_000 ? ts / 1000 : ts
        let age = now.timeIntervalSince1970 - seconds
        return age >= -window && age < window
    }
}

struct RequestRowBackground: View {
    var selected: Bool
    var key: String?
    @ObservedObject var hover: RowHover

    var body: some View {
        ZStack(alignment: .leading) {
            fill
            if selected {
                Rectangle().fill(LogXTheme.accent).frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(LogXTheme.divider).frame(height: 1)
        }
        .animation(LogXMotion.hover, value: hovered)
        .onHover(perform: track)
    }

    private func track(_ inside: Bool) {
        guard let key else { return }
        hover.update(key, inside: inside)
    }

    private var hovered: Bool { key != nil && hover.key == key }

    private var fill: Color {
        if selected { return LogXTheme.selection }
        return hovered ? LogXTheme.panel2.opacity(0.6) : Color.clear
    }
}
