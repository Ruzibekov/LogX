import Foundation

public enum JSONFind {
    public static func matches(_ text: String, query: String) -> [Range<String.Index>] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !text.isEmpty else { return [] }
        var out: [Range<String.Index>] = []
        var search = text.startIndex
        while search < text.endIndex {
            guard let range = text.range(of: q, options: .caseInsensitive, range: search..<text.endIndex) else {
                break
            }
            out.append(range)
            if range.lowerBound == range.upperBound {
                if range.upperBound < text.endIndex {
                    search = text.index(after: range.upperBound)
                } else {
                    break
                }
            } else {
                search = range.upperBound
            }
        }
        return out
    }

    public static func nextIndex(current: Int, count: Int, reverse: Bool = false) -> Int {
        guard count > 0 else { return 0 }
        let cur = ((current % count) + count) % count
        if reverse {
            return (cur - 1 + count) % count
        }
        return (cur + 1) % count
    }
}
