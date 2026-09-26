import SwiftUI
import LogXCore

struct PendingSchedule: TimelineSchedule {
    static let liveStep: TimeInterval = 0.1
    static let staleStep: TimeInterval = 1

    let staleAt: Date?

    init(ts: Double?) {
        staleAt = PendingClock.staleAt(ts: ts)
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var next = startDate
        let staleAt = staleAt
        return AnyIterator {
            let current = next
            let live = staleAt.map { current < $0 } ?? false
            next = current.addingTimeInterval(live ? Self.liveStep : Self.staleStep)
            return current
        }
    }
}

struct PendingTicker<Content: View>: View {
    var ts: Double?
    @ViewBuilder var content: (_ stale: Bool, _ elapsed: String) -> Content

    var body: some View {
        TimelineView(PendingSchedule(ts: ts)) { context in
            content(PendingClock.isStale(ts: ts, now: context.date), PendingClock.label(ts: ts, now: context.date))
        }
    }
}

struct PendingElapsed: View {
    var ts: Double?
    var font: Font

    var body: some View {
        PendingTicker(ts: ts) { _, elapsed in
            Text(elapsed)
                .font(font)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityLabel("Kutilmoqda")
    }
}

struct PendingStatusMark: View {
    var ts: Double?
    var spinner: ControlSize
    var staleSize: CGFloat

    var body: some View {
        PendingTicker(ts: ts) { stale, _ in
            ZStack {
                if stale {
                    Image(systemName: "hourglass")
                        .font(.system(size: staleSize, weight: .regular))
                        .foregroundStyle(LogXTheme.muted)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .controlSize(spinner)
                        .transition(.opacity)
                }
            }
            .animation(LogXMotion.statusCrossfade, value: stale)
            .help(stale ? "Javob \(Int(PendingClock.staleAfter / 60)) daqiqadan beri kelmadi" : "Javob kutilmoqda")
        }
    }
}

struct PendingResponseView: View {
    var ts: Double?

    var body: some View {
        PendingTicker(ts: ts) { stale, elapsed in
            VStack(spacing: 10) {
                PendingStatusMark(ts: ts, spinner: .small, staleSize: 16)
                Text(stale ? "Javob kelmadi" : "Javob kutilmoqda")
                    .font(LogXType.ui(LogXType.body, .medium))
                    .foregroundStyle(LogXTheme.text2)
                Text(elapsed)
                    .font(LogXType.mono(LogXType.caption))
                    .monospacedDigit()
                    .foregroundStyle(LogXTheme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(stale ? "Javob kelmadi" : "Javob kutilmoqda")
        }
    }
}
