import SwiftUI
import LogXCore

struct RequestRow: View {
    @EnvironmentObject private var store: LogStore
    var log: NetworkLog
    var selected: Bool
    var now: Date
    @State private var hovered = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(selected ? LogXTheme.accent : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 3)

            HStack {
                Text(log.method)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(LogXTheme.methodColor(log.method))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(LogXTheme.panel2))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(LogXTheme.line, lineWidth: 1))
            }
            .frame(width: 58, alignment: .leading)

            Text(log.responseCode.map(String.init) ?? "NET")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(LogXTheme.status(log.statusClass))
                .frame(width: 44, alignment: .leading)
                .help(log.statusDescription)

            VStack(alignment: .leading, spacing: 1) {
                if !log.hostLabel.isEmpty {
                    Text(log.hostLabel)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(LogXTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: 6) {
                    Text(store.displayPath(log))
                        .font(.system(size: 11.5, weight: selected ? .medium : .regular, design: .monospaced))
                        .foregroundStyle(selected ? LogXTheme.text : LogXTheme.text2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(store.shareableURL(log))

                    let repeats = store.repeatCount(for: log)
                    if repeats > 1 {
                        Button {
                            store.filterEndpoint(log)
                        } label: {
                            Text("×\(repeats)")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(LogXTheme.accentLight)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(LogXTheme.chipOn, in: RoundedRectangle(cornerRadius: 3.5))
                        }
                        .buttonStyle(.plain)
                        .help("Shu endpoint \(repeats) marta — bosilsa faqat shular qoladi")
                        .accessibilityLabel("Shu endpointni filtrlash")
                    }

                    if store.diffAnchorKey == log.key {
                        Text("A")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(LogXTheme.err)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(LogXTheme.err.opacity(0.14), in: RoundedRectangle(cornerRadius: 3.5))
                            .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(LogXTheme.err.opacity(0.4), lineWidth: 1))
                            .help("Solishtirish uchun belgilangan — boshqa so'rovda ⇧⌘D")
                    }

                    if Replay.isReplay(log) {
                        Text("REPLAY")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(LogXTheme.accentLight)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(LogXTheme.chipOn, in: RoundedRectangle(cornerRadius: 3.5))
                            .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(LogXTheme.chipOnEdge, lineWidth: 1))
                            .help("Mac'dan qayta yuborilgan so'rov")
                    }

                    if RelativeTime.isFresh(ts: log.ts, now: now) {
                        Text("YANGI")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.7)
                            .foregroundStyle(LogXTheme.ok)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(LogXTheme.ok.opacity(0.14), in: RoundedRectangle(cornerRadius: 3.5))
                            .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(LogXTheme.ok.opacity(0.35), lineWidth: 1))
                    }

                    if hovered || copied {
                        Button {
                            store.copy(store.shareableURL(log), what: "URL")
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9.5))
                                .foregroundStyle(copied ? LogXTheme.ok : LogXTheme.muted)
                        }
                        .buttonStyle(.plain)
                        .help(copied ? "Nusxalandi!" : "URL nusxalash")
                        .accessibilityLabel("URL nusxalash")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(log.formattedDuration)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(durationColor)
                .frame(width: 58, alignment: .trailing)

            Text(RelativeTime.clock(ts: log.ts))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(LogXTheme.muted2)
                .frame(width: 58, alignment: .trailing)
                .help(RelativeTime.label(ts: log.ts, now: now))

            Text(log.appShortLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LogXTheme.muted)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 3.5))
                .frame(width: 76, alignment: .trailing)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(log.appLabel)

            hoverStar.frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: log.hostLabel.isEmpty ? 38 : 46)
        .background(selected ? LogXTheme.selection : (hovered ? LogXTheme.panel2 : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { store.selectLog(log) }
        .onHover { hovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(log.method) \(log.responseCode.map(String.init) ?? "NET") \(store.displayPath(log))")
    }

    @ViewBuilder
    private var hoverStar: some View {
        if hovered || store.isFavorite(log.key) {
            Button {
                store.toggleFavorite(log.key)
            } label: {
                Image(systemName: store.isFavorite(log.key) ? "star.fill" : "star")
                    .font(.system(size: 10.5))
                    .foregroundStyle(store.isFavorite(log.key) ? LogXTheme.warn : LogXTheme.muted2)
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
        return LogXTheme.muted
    }
}
