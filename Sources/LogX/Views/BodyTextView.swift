import AppKit
import SwiftUI
import LogXCore

/// Tana matni NSTextView'da: tanlash, o'rash/gorizontal aylanma va faol topilmaga scroll.
struct BodyTextView: NSViewRepresentable {
    var text: NSAttributedString
    var wrap: Bool
    var activeRange: NSRange?
    var fontSize: CGFloat = 11.5

    final class Coordinator {
        var lastText: NSAttributedString?
        var lastWrap: Bool?
        var lastActive: NSRange?
        var lastFontSize: CGFloat?
        private var observer: NSObjectProtocol?

        func observe(scroll: NSScrollView, gutter: LineNumberGutter) {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scroll.contentView,
                queue: .main
            ) { [weak gutter] _ in
                gutter?.needsDisplay = true
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> BodyContainerView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.textContainerInset = NSSize(width: 12, height: 14)
        textView.font = JSONHighlighter.bodyFont(size: fontSize)
        textView.textColor = JSONHighlighter.nsColor(.plain)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.setAccessibilityLabel("So'rov tanasi")
        scroll.documentView = textView

        scroll.contentView.postsBoundsChangedNotifications = true

        let gutter = LineNumberGutter(textView: textView, scroll: scroll, fontSize: fontSize)
        context.coordinator.observe(scroll: scroll, gutter: gutter)
        return BodyContainerView(scroll: scroll, gutter: gutter)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BodyContainerView, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 320
        let height = proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? 240
        return CGSize(width: width, height: height)
    }

    func updateNSView(_ nsView: BodyContainerView, context: Context) {
        let scroll = nsView.scroll
        guard let textView = scroll.documentView as? NSTextView, let container = textView.textContainer else { return }
        let coord = context.coordinator
        if coord.lastFontSize != fontSize {
            coord.lastFontSize = fontSize
            textView.font = JSONHighlighter.bodyFont(size: fontSize)
            nsView.gutter.apply(fontSize: fontSize)
        }
        if coord.lastWrap != wrap {
            coord.lastWrap = wrap
            if wrap {
                container.widthTracksTextView = true
                container.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                textView.setFrameSize(NSSize(width: scroll.contentSize.width, height: textView.frame.height))
                scroll.hasHorizontalScroller = false
            } else {
                container.widthTracksTextView = false
                container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                container.lineBreakMode = .byClipping
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = []
                scroll.hasHorizontalScroller = true
            }
            textView.layoutManager?.ensureLayout(for: container)
            textView.sizeToFit()
        }
        if coord.lastText !== text {
            coord.lastText = text
            textView.textStorage?.setAttributedString(text)
            nsView.gutter.needsDisplay = true
            coord.lastActive = nil
            if activeRange == nil {
                textView.scroll(.zero)
            }
        }
        if let activeRange, coord.lastActive != activeRange, activeRange.location + activeRange.length <= (textView.textStorage?.length ?? 0) {
            coord.lastActive = activeRange
            textView.scrollRangeToVisible(activeRange)
        }
    }
}
