import AppKit

extension BodyTextView {
    static let revealDuration: TimeInterval = 0.3

    static func centeredOrigin(target: NSRect, viewport: NSSize, document: NSSize, current: NSPoint) -> NSPoint {
        let maxX = max(0, document.width - viewport.width)
        let maxY = max(0, document.height - viewport.height)
        let fitsX = target.minX >= current.x && target.maxX <= current.x + viewport.width
        let x = fitsX ? min(current.x, maxX) : min(max(target.midX - viewport.width / 2, 0), maxX)
        let y = min(max(target.midY - viewport.height / 2, 0), maxY)
        return NSPoint(x: x.rounded(), y: y.rounded())
    }

    static func reveal(_ range: NSRange, textView: NSTextView, scroll: NSScrollView, animate: Bool, indicate: Bool) {
        guard let layout = textView.layoutManager, let container = textView.textContainer else { return }
        layout.ensureLayout(forCharacterRange: NSRange(location: 0, length: NSMaxRange(range)))
        let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let origin = textView.textContainerOrigin
        let target = layout.boundingRect(forGlyphRange: glyphs, in: container).offsetBy(dx: origin.x, dy: origin.y)
        let clip = scroll.contentView
        let needed = target.maxY + clip.bounds.height
        layout.ensureLayout(forBoundingRect: NSRect(x: 0, y: 0, width: container.size.width, height: needed), in: container)
        if textView.frame.maxY < min(needed, layout.usedRect(for: container).maxY) || textView.frame.maxX < target.maxX {
            textView.sizeToFit()
        }
        let destination = centeredOrigin(
            target: target,
            viewport: clip.bounds.size,
            document: textView.frame.size,
            current: clip.bounds.origin
        )
        guard animate, textView.window != nil else {
            clip.setBoundsOrigin(destination)
            scroll.reflectScrolledClipView(clip)
            if indicate, textView.window != nil {
                textView.showFindIndicator(for: range)
            }
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = revealDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            clip.animator().setBoundsOrigin(destination)
        } completionHandler: { [weak textView, weak scroll] in
            guard let textView, let scroll else { return }
            scroll.reflectScrolledClipView(scroll.contentView)
            let settled = scroll.contentView.bounds.origin == destination
            if indicate, settled, NSMaxRange(range) <= (textView.textStorage?.length ?? 0) {
                textView.showFindIndicator(for: range)
            }
        }
    }
}
