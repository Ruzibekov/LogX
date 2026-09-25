import AppKit

final class LineNumberGutter: NSView {
    private weak var textView: NSTextView?
    private weak var scroll: NSScrollView?
    private var fontSize: CGFloat

    static let width: CGFloat = 46

    init(textView: NSTextView, scroll: NSScrollView, fontSize: CGFloat) {
        self.textView = textView
        self.scroll = scroll
        self.fontSize = fontSize
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) ishlatilmaydi")
    }

    override var isFlipped: Bool { true }

    func apply(fontSize: CGFloat) {
        guard self.fontSize != fontSize else { return }
        self.fontSize = fontSize
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        LogXTheme.dynamicNS(LogXPalette.well).setFill()
        bounds.fill()
        LogXTheme.dynamicNS(LogXPalette.well).setFill()
        NSRect(x: bounds.maxX - 1, y: 0, width: 1, height: bounds.height).fill()

        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer,
              let scroll else { return }

        let content = textView.string as NSString
        guard content.length > 0 else { return }

        let visible = scroll.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        var number = 1
        if charRange.location > 0 {
            content.enumerateSubstrings(
                in: NSRange(location: 0, length: charRange.location),
                options: [.byLines, .substringNotRequired]
            ) { _, _, _, _ in number += 1 }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: LogXFonts.nsMono(max(9, fontSize - 1.5)),
            .foregroundColor: LogXTheme.dynamicNS(LogXPalette.muted2),
        ]

        var index = charRange.location
        while index <= NSMaxRange(charRange), index < content.length {
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = fragment.minY + textView.textContainerInset.height - visible.minY
            let label = "\(number)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(
                at: NSPoint(x: bounds.maxX - size.width - 10, y: y + (fragment.height - size.height) / 2),
                withAttributes: attributes
            )
            number += 1
            index = NSMaxRange(lineRange)
            if lineRange.length == 0 { break }
        }
    }
}

final class BodyContainerView: NSView {
    let gutter: LineNumberGutter
    let scroll: NSScrollView
    var pendingReveal: (() -> Void)?

    init(scroll: NSScrollView, gutter: LineNumberGutter) {
        self.scroll = scroll
        self.gutter = gutter
        super.init(frame: .zero)
        addSubview(gutter)
        addSubview(scroll)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) ishlatilmaydi")
    }

    override func layout() {
        super.layout()
        let width = LineNumberGutter.width
        gutter.frame = NSRect(x: 0, y: 0, width: width, height: bounds.height)
        scroll.frame = NSRect(x: width, y: 0, width: max(0, bounds.width - width), height: bounds.height)
        gutter.needsDisplay = true
        guard let reveal = pendingReveal, bounds.height > 0 else { return }
        pendingReveal = nil
        scroll.layoutSubtreeIfNeeded()
        reveal()
    }
}
