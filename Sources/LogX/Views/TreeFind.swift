import SwiftUI
import LogXCore

final class TreeFinder {
    private var identity: String?
    private var query: String?
    private var cached: [String] = []
    private(set) var computations = 0

    func matches(in tree: JSONTree, query: String) -> [String] {
        if identity == tree.identity, self.query == query { return cached }
        identity = tree.identity
        self.query = query
        cached = tree.matches(query: query)
        computations += 1
        return cached
    }
}

enum TreeFindHighlight {
    static let activeBackground = LogXTheme.warn.opacity(0.42)
    static let matchBackground = LogXTheme.accent.opacity(0.26)

    static func text(_ value: String, query: String, active: Bool) -> AttributedString {
        var result = AttributedString(value)
        let background = active ? activeBackground : matchBackground
        for range in JSONFind.matches(value, query: query) {
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result) else { continue }
            result[lower..<upper].backgroundColor = background
        }
        return result
    }
}
