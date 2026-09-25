import AppKit
import SwiftUI

enum LogXMotion {
    static let rowInsertDuration: Double = 0.18
    static let statusCrossfadeDuration: Double = 0.2
    static let signalShiftDuration: Double = 0.24
    static let pressDuration: Double = 0.12
    static let hoverDuration: Double = 0.12
    static let livePulseDuration: Double = 1.6
    static let rowInsertOffset: CGFloat = 6
    static let pressScale: CGFloat = 0.97

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func gated(_ animation: Animation, reduce: Bool = reduceMotion) -> Animation? {
        reduce ? nil : animation
    }

    static var rowInsert: Animation? { gated(.easeOut(duration: rowInsertDuration)) }
    static var statusCrossfade: Animation? { gated(.easeOut(duration: statusCrossfadeDuration)) }
    static var signalShift: Animation? { gated(.easeOut(duration: signalShiftDuration)) }
    static var hover: Animation? { gated(.easeOut(duration: hoverDuration)) }
    static var expand: Animation? { gated(.easeOut(duration: rowInsertDuration)) }
    static var snappy: Animation? { gated(.spring(response: 0.25, dampingFraction: 0.85)) }
    static var settle: Animation? { gated(.spring(response: 0.28, dampingFraction: 0.86)) }
    static var livePulse: Animation? {
        gated(.easeInOut(duration: livePulseDuration).repeatForever(autoreverses: true))
    }

    static func press(reduce: Bool) -> Animation? {
        gated(.easeOut(duration: pressDuration), reduce: reduce)
    }

    static func perform(_ animation: Animation?, _ body: () -> Void) {
        if let animation {
            withAnimation(animation, body)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, body)
        }
    }
}

struct LiveDot: View {
    var tint: Color
    var pulsing: Bool
    var size: CGFloat = 6
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: size, height: size)
            .opacity(pulsing && dim ? 0.35 : 1)
            .onAppear { restart() }
            .onChange(of: pulsing) { _, _ in restart() }
            .accessibilityHidden(true)
    }

    private func restart() {
        guard pulsing, let pulse = LogXMotion.livePulse else {
            LogXMotion.perform(nil) { dim = false }
            return
        }
        LogXMotion.perform(nil) { dim = false }
        withAnimation(pulse) { dim = true }
    }
}
