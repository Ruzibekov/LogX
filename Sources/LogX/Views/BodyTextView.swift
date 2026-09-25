import AppKit
import SwiftUI
import LogXCore

/// Tana matni NSTextView'da: tanlash, o'rash/gorizontal aylanma va faol topilmaga scroll.
struct BodyTextView: NSViewRepresentable {
    var text: NSAttributedString
    var wrap: Bool
    var activeRange: NSRange?
    var fontSize: CGFloat = 11.5
    var contentID: String?

    final class Coordinator {
        var lastText: NSAttributedString?
        var lastWrap: Bool?
        var lastActive: NSRange?
        var lastFontSize: CGFloat?
        var lastContentID: String?
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

        func apply(to view: BodyContainerView, text: NSAttributedString, wrap: Bool, activeRange: NSRange?, fontSize: CGFloat, contentID: String?, animate: Bool) {
            let scroll = view.scroll
            guard let textView = scroll.documentView as? NSTextView, let container = textView.textContainer else { return }
            if lastFontSize != fontSize {
                lastFontSize = fontSize
                textView.font = JSONHighlighter.bodyFont(size: fontSize)
                view.gutter.apply(fontSize: fontSize)
                lastActive = nil
            }
            if lastWrap != wrap {
                lastWrap = wrap
                BodyTextView.applyWrap(wrap, textView: textView, container: container, scroll: scroll)
            }
            if lastText !== text {
                lastText = text
                textView.textStorage?.setAttributedString(text)
                view.gutter.needsDisplay = true
                if contentID == nil || contentID != lastContentID {
                    lastContentID = contentID
                    lastActive = nil
                    if activeRange == nil {
                        textView.scroll(.zero)
                    }
                }
            }
            guard let activeRange else {
                lastActive = nil
                view.pendingReveal = nil
                return
            }
            if lastActive != activeRange, NSMaxRange(activeRange) <= (textView.textStorage?.length ?? 0) {
                lastActive = activeRange
                guard scroll.contentView.bounds.height > 0 else {
                    view.pendingReveal = { [weak textView, weak scroll] in
                        guard let textView, let scroll else { return }
                        BodyTextView.reveal(activeRange, textView: textView, scroll: scroll, animate: false, indicate: animate)
                    }
                    return
                }
                view.pendingReveal = nil
                BodyTextView.reveal(activeRange, textView: textView, scroll: scroll, animate: animate, indicate: animate)
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func makeContainer(fontSize: CGFloat) -> BodyContainerView {
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
        return BodyContainerView(scroll: scroll, gutter: gutter)
    }

    func makeNSView(context: Context) -> BodyContainerView {
        let view = Self.makeContainer(fontSize: fontSize)
        context.coordinator.observe(scroll: view.scroll, gutter: view.gutter)
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BodyContainerView, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 320
        let height = proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? 240
        return CGSize(width: width, height: height)
    }

    func updateNSView(_ nsView: BodyContainerView, context: Context) {
        context.coordinator.apply(
            to: nsView,
            text: text,
            wrap: wrap,
            activeRange: activeRange,
            fontSize: fontSize,
            contentID: contentID,
            animate: !LogXMotion.reduceMotion
        )
    }

    static func applyWrap(_ wrap: Bool, textView: NSTextView, container: NSTextContainer, scroll: NSScrollView) {
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
}
