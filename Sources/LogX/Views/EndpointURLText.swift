import SwiftUI

struct EndpointURLText: View {
    let raw: String
    let size: CGFloat
    var weight: Font.Weight = .medium
    var selectable = false
    var mono = false

    var body: some View {
        let parts = mono ? URLStyle.monoPathAndQuery(raw, size: size) : URLStyle.pathAndQuery(raw, size: size, weight: weight)
        EndpointSplitLayout {
            Text(parts.path)
                .lineLimit(1)
                .truncationMode(.head)
            if let query = parts.query {
                Text(query)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .modifier(SelectableText(enabled: selectable))
    }
}

struct EndpointSplitLayout: Layout {
    var queryShare: CGFloat = 0.45

    func widths(available: CGFloat, path: CGFloat, query: CGFloat) -> (path: CGFloat, query: CGFloat) {
        guard path + query > available else { return (path, query) }
        let queryWidth = min(query, max(available * queryShare, available - path))
        return (max(0, available - queryWidth), queryWidth)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let total = ideals.reduce(0) { $0 + $1.width }
        let height = ideals.map(\.height).max() ?? 0
        guard let width = proposal.width else { return CGSize(width: total, height: height) }
        return CGSize(width: min(width, total), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        let split: (path: CGFloat, query: CGFloat) = ideals.count > 1
            ? widths(available: bounds.width, path: ideals[0], query: ideals[1])
            : (bounds.width, 0)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = index == 0 ? split.path : split.query
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width
        }
    }
}

private struct SelectableText: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.textSelection(.enabled)
        } else {
            content
        }
    }
}
