import SwiftUI
import LogXCore

struct DetailStatusHero: View {
    var log: NetworkLog
    var facts: [DetailFact]
    var compact: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
                .id(HeroIdentity(key: log.key, pending: log.isPending))
                .transition(.opacity)
        }
        .animation(LogXMotion.statusCrossfade, value: HeroIdentity(key: log.key, pending: log.isPending))
        .accessibilityElement(children: .combine)
    }

    private var content: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 28) {
                codeBlock
                factsRow
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 10) {
                codeBlock
                WrapLayout(spacing: 22, lineSpacing: 10) {
                    ForEach(facts, id: \.self) { factView($0) }
                }
            }
        }
    }

    private var codeSize: CGFloat { compact ? 34 : LogXType.statusHero }

    @ViewBuilder
    private var codeBlock: some View {
        if log.isPending {
            pendingBlock
        } else {
            answeredBlock
        }
    }

    private var pendingBlock: some View {
        PendingTicker(ts: log.ts) { stale, elapsed in
            HStack(alignment: .center, spacing: 12) {
                PendingStatusMark(ts: log.ts, spinner: compact ? .small : .regular, staleSize: compact ? 18 : 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stale ? "Javob kelmadi" : log.statusDescription)
                        .font(LogXType.mono(compact ? 13 : 18))
                        .foregroundStyle(LogXTheme.text2)
                    Text(elapsed)
                        .font(LogXType.mono(compact ? 12 : 14))
                        .monospacedDigit()
                        .foregroundStyle(LogXTheme.muted)
                }
            }
            .frame(minHeight: compact ? 34 : 56, alignment: .leading)
            .accessibilityLabel(stale ? "Javob kelmadi" : "Javob kutilmoqda")
        }
    }

    private var answeredBlock: some View {
        let reason = log.statusDescription
        let short = DetailFacts.reasonIsShort(reason)
        return HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(DetailFacts.codeLabel(log))
                .font(LogXType.mono(codeSize, .ultraLight))
                .tracking(-codeSize * 0.06)
                .foregroundStyle(LogXTheme.status(log.statusClass))
                .lineLimit(1)
                .fixedSize()
                .help(reason)
            Text(reason)
                .font(short ? LogXType.mono(compact ? 13 : 18) : LogXType.ui(LogXType.body, .medium))
                .foregroundStyle(LogXTheme.muted)
                .lineLimit(2)
                .frame(maxWidth: short ? nil : 260, alignment: .leading)
                .fixedSize(horizontal: short, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.vertical, compact ? 0 : -6)
    }

    private struct HeroIdentity: Hashable {
        let key: String
        let pending: Bool
    }

    private var factsRow: some View {
        HStack(alignment: .bottom, spacing: 22) {
            ForEach(facts, id: \.self) { factView($0) }
        }
        .padding(.bottom, compact ? 2 : 6)
        .fixedSize()
    }

    private func factView(_ fact: DetailFact) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(fact.label)
                .font(LogXType.ui(11, .medium))
                .foregroundStyle(LogXTheme.muted)
            Text(fact.value)
                .font(LogXType.mono(LogXType.body, .medium))
                .foregroundStyle(LogXTheme.text)
                .textSelection(.enabled)
        }
        .lineLimit(1)
        .fixedSize()
    }
}
