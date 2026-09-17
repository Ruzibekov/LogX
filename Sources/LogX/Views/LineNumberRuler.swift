import AppKit

final class LineNumberRuler: NSRulerView {
    private var fontSize: CGFloat

    init(textView: NSTextView, fontSize: CGFloat) {
        self.fontSize = fontSize
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 46
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) ishlatilmaydi")
    }

    func apply(fontSize: CGFloat) {
        guard self.fontSize != fontSize else { return }
        self.fontSize = fontSize
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        LogXTheme.dynamicNS(dark: 0x0A0C0F, light: 0xF2F5F9).setFill()
        rect.fill()
        LogXTheme.dynamicNS(dark: 0x1B1F25, light: 0xE7EBF0).setFill()
        NSRect(x: bounds.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()

        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let content = textView.string as NSString
        guard content.length > 0 else { return }

        let visible = scrollView?.contentView.bounds ?? .zero
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
            .font: NSFont.monospacedSystemFont(ofSize: max(9, fontSize - 1.5), weight: .regular),
            .foregroundColor: LogXTheme.dynamicNS(dark: 0x4C545F, light: 0x737C89),
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
