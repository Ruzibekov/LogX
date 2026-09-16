import SwiftUI

/// Oqim (flow) konteyneri: sig'magan chip/tugma keyingi qatorga o'tadi.
/// Keng oynada hammasi bir qatorda, torayganda qatorma-qator oqadi —
/// matn hech qachon o'rtadan yorilib ketmaydi.
struct WrapLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let items = subviews.map { $0.sizeThatFits(.unspecified) }
        return WrapLayout.rects(items: items, maxWidth: proposal.width, spacing: spacing, lineSpacing: lineSpacing).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let items = subviews.map { $0.sizeThatFits(.unspecified) }
        let placed = WrapLayout.rects(items: items, maxWidth: bounds.width, spacing: spacing, lineSpacing: lineSpacing)
        for (index, subview) in subviews.enumerated() {
            let rect = placed.rects[index]
            subview.place(
                at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: rect.width, height: rect.height)
            )
        }
    }

    /// Yotiq joylashuv sof hisobi — Layout protokoli va unit testlar bitta
    /// manbadan ishlatadi, o'lchash bilan joylashturish farq qilmaydi.
    static func rects(items: [CGSize], maxWidth: CGFloat?, spacing: CGFloat, lineSpacing: CGFloat) -> (rects: [CGRect], size: CGSize) {
        guard !items.isEmpty else { return ([], .zero) }
        var out: [CGRect] = []
        out.reserveCapacity(items.count)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var width: CGFloat = 0
        for item in items {
            if x > 0, let maxWidth, x + item.width > maxWidth {
                width = max(width, x - spacing)
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            out.append(CGRect(x: x, y: y, width: item.width, height: item.height))
            x += item.width + spacing
            lineHeight = max(lineHeight, item.height)
        }
        width = max(0, max(width, x - spacing))
        return (out, CGSize(width: width, height: y + lineHeight))
    }
}
