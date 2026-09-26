import AppKit
import SwiftUI
import LogXCore

/// Ikki so'rovni bo'lim bo'yicha solishtirish: A (eski) → B (yangi), unified
/// ko'rinish, faqat farqlar rejimi, nusxalash. Diff asosiy oqimdan tashqarida hisoblanadi.
struct DiffView: View {
    let pair: DiffPair
    @EnvironmentObject private var store: LogStore
    @State private var section: LogDiff.Section = .response
    @AppStorage("logx.diffOnlyChanges") private var onlyChanges = true
    @State private var rendered: RenderedDiff?

    private struct RenderKey: Equatable {
        var pairID: String
        var section: LogDiff.Section
        var redact: Bool
        var onlyChanges: Bool
    }

    private var key: RenderKey {
        RenderKey(pairID: pair.id, section: section, redact: store.redactEnabled, onlyChanges: onlyChanges)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(LogXTheme.divider)
            controls
            Divider().overlay(LogXTheme.divider)
            content
            Divider().overlay(LogXTheme.divider)
            footer
        }
        .frame(minWidth: 720, idealWidth: 920, minHeight: 480, idealHeight: 640)
        .background(LogXTheme.panel)
        .task(id: key) {
            let k = key
            let redact = k.redact
            let sec = k.section
            let only = k.onlyChanges
            let a = pair.a
            let b = pair.b
            let next = await Task.detached(priority: .userInitiated) {
                RenderedDiff.make(a: a, b: b, section: sec, redact: redact, onlyChanges: only)
            }.value
            guard !Task.isCancelled else { return }
            rendered = next
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            sideCard(label: "A", log: pair.a, tint: LogXTheme.err)
            Button {
                store.swapDiff()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(LogXType.ui(LogXType.meta, .semibold))
                    .foregroundStyle(LogXTheme.muted)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LogXTheme.well))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("A va B o'rnini almashtirish")
            .accessibilityLabel("Tomonlarni almashtirish")
            sideCard(label: "B", log: pair.b, tint: LogXTheme.ok)
        }
        .padding(12)
    }

    private func sideCard(label: String, log: NetworkLog, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(LogXType.mono(LogXType.meta, .bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .background(RoundedRectangle(cornerRadius: 4).fill(tint.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(tint.opacity(0.45), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(log.method.uppercased())
                        .font(LogXType.mono(LogXType.caption, .bold))
                        .foregroundStyle(LogXTheme.text2)
                    Text(store.displayPath(log))
                        .font(LogXType.mono(LogXType.body))
                        .foregroundStyle(LogXTheme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(store.shareableURL(log))
                }
                HStack(spacing: 8) {
                    Text(log.statusCodeLabel)
                        .font(LogXType.mono(LogXType.caption, .bold))
                        .foregroundStyle(LogXTheme.status(log.statusClass))
                    Text(log.formattedDuration)
                        .font(LogXType.mono(LogXType.caption))
                        .foregroundStyle(LogXTheme.muted)
                    Text(RelativeTime.stamp(ts: log.ts))
                        .font(LogXType.mono(LogXType.caption))
                        .foregroundStyle(LogXTheme.muted2)
                    if Replay.isReplay(log) {
                        Text("REPLAY")
                            .font(LogXType.ui(LogXType.caption, .bold))
                            .tracking(0.6)
                            .foregroundStyle(LogXTheme.accentLight)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(LogXTheme.well))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
    }

    private var controls: some View {
        HStack(spacing: 5) {
            ForEach(LogDiff.Section.allCases, id: \.self) { item in
                Button {
                    LogXMotion.perform(LogXMotion.snappy) { section = item }
                } label: {
                    Text(item.title)
                        .font(LogXType.ui(LogXType.body, section == item ? .semibold : .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(section == item ? LogXTheme.chipOn : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(section == item ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1))
                        .foregroundStyle(section == item ? LogXTheme.text : LogXTheme.muted)
                }
                .buttonStyle(LogXPressStyle())
            }
            Spacer(minLength: 8)
            if let rendered {
                stats(rendered)
            }
            Toggle(isOn: $onlyChanges) {
                Text("Faqat farqlar")
                    .font(LogXType.ui(LogXType.caption, .semibold))
                    .foregroundStyle(onlyChanges ? LogXTheme.accentLight : LogXTheme.muted)
                    .lineLimit(1)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .fixedSize()
            .help("Bir xil qatorlar yig'iladi, o'zgarish atrofida 3 qator qoladi")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(LogXTheme.well)
    }

    private func stats(_ rendered: RenderedDiff) -> some View {
        HStack(spacing: 6) {
            if rendered.diff.identical {
                Text("Farq yo'q")
                    .font(LogXType.ui(LogXType.caption, .semibold))
                    .foregroundStyle(LogXTheme.ok)
            } else {
                Text("+\(rendered.diff.inserted)")
                    .font(LogXType.mono(LogXType.caption, .bold))
                    .foregroundStyle(LogXTheme.ok)
                Text("−\(rendered.diff.deleted)")
                    .font(LogXType.mono(LogXType.caption, .bold))
                    .foregroundStyle(LogXTheme.err)
            }
            if rendered.diff.truncated {
                Text("· juda katta, blok sifatida")
                    .font(LogXType.ui(LogXType.caption))
                    .foregroundStyle(LogXTheme.warn)
                    .help("Ikki tomon ham juda uzun — qatorma-qator tekislash o'rniga eski blok o'chdi, yangisi qo'shildi deb ko'rsatildi")
            }
        }
        .padding(.trailing, 6)
    }

    @ViewBuilder
    private var content: some View {
        if let rendered {
            if rendered.diff.identical {
                VStack(spacing: 8) {
                    Image(systemName: "equal.circle")
                        .font(LogXType.ui(LogXType.display, .semibold))
                        .foregroundStyle(LogXTheme.ok)
                    Text("\(section.title) bir xil")
                        .font(LogXType.ui(LogXType.title))
                        .foregroundStyle(LogXTheme.text2)
                    Text("Boshqa bo'limni tanlang yoki tomonlarni almashtiring")
                        .font(LogXType.ui(LogXType.meta))
                        .foregroundStyle(LogXTheme.muted2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                BodyTextView(text: rendered.attributed, wrap: false, activeRange: nil)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LogXTheme.well)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(LogXTheme.line, lineWidth: 1))
                    )
                    .padding(10)
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Diffni nusxalash") {
                store.copy(rendered?.unified ?? "", what: "diff")
            }
            .buttonStyle(LogXPressStyle())
            .disabled(rendered == nil || rendered?.diff.identical == true)
            .help("Unified ko'rinishni (+/−) nusxalash")
            Text("Esc yopadi · ⌘D belgilaydi · ⇧⌘D belgilangan bilan solishtiradi")
                .font(LogXType.ui(LogXType.caption))
                .foregroundStyle(LogXTheme.muted2)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Yopish") { store.closeDiff() }
                .buttonStyle(LogXPressStyle())
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct RenderedDiff {
    var diff: TextDiff
    var lines: [DiffLine]
    var attributed: NSAttributedString
    var unified: String

    static func make(a: NetworkLog, b: NetworkLog, section: LogDiff.Section, redact: Bool, onlyChanges: Bool) -> RenderedDiff {
        let diff = LogDiff.diff(a, b, section: section, redact: redact)
        let lines = onlyChanges ? diff.compact() : diff.lines
        return RenderedDiff(diff: diff, lines: lines, attributed: attributed(lines), unified: TextDiff.unified(lines))
    }

    static let insertBg = LogXTheme.dynamicNS(LogXPalette.ok).withAlphaComponent(0.16)
    static let deleteBg = LogXTheme.dynamicNS(LogXPalette.err).withAlphaComponent(0.16)
    static let changedFg = LogXTheme.dynamicNS(LogXPalette.text)

    static func pad(_ n: Int?) -> String {
        let s = n.map(String.init) ?? ""
        return String(repeating: " ", count: max(0, 5 - s.count)) + s
    }

    static func attributed(_ lines: [DiffLine]) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let font = JSONHighlighter.bodyFont
        let gutterFont = LogXFonts.nsMono(10.5)
        for (i, line) in lines.enumerated() {
            let prefix: String
            let color: NSColor
            let bg: NSColor?
            switch line.op {
            case .same:
                prefix = "  "
                color = JSONHighlighter.nsColor(.plain)
                bg = nil
            case .insert:
                prefix = "+ "
                color = changedFg
                bg = insertBg
            case .delete:
                prefix = "- "
                color = changedFg
                bg = deleteBg
            case .gap:
                prefix = ""
                color = JSONHighlighter.nsColor(.punct)
                bg = nil
            }
            let gutter = line.op == .gap ? "" : pad(line.oldLine) + " " + pad(line.newLine) + " "
            let text = gutter + prefix + line.text + (i == lines.count - 1 ? "" : "\n")
            var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            if let bg { attrs[.backgroundColor] = bg }
            let piece = NSMutableAttributedString(string: text, attributes: attrs)
            if !gutter.isEmpty {
                piece.addAttributes([.font: gutterFont, .foregroundColor: JSONHighlighter.nsColor(.punct)], range: NSRange(location: 0, length: gutter.utf16.count))
            }
            out.append(piece)
        }
        return out
    }
}
