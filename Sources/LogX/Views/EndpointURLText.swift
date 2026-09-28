import SwiftUI

struct EndpointURLText: View {
    let raw: String
    let size: CGFloat
    var weight: Font.Weight = .medium
    var selectable = false
    var mono = false

    var body: some View {
        let parts = mono ? URLStyle.monoPathAndQuery(raw, size: size) : URLStyle.pathAndQuery(raw, size: size, weight: weight)
        HStack(spacing: 0) {
            Text(parts.path)
                .lineLimit(1)
                .truncationMode(.head)
                .layoutPriority(1)
            if let query = parts.query {
                Text(query)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .modifier(SelectableText(enabled: selectable))
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
