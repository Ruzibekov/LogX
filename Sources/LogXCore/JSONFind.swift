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

    public static func count(_ text: String, query: String) -> Int {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !text.isEmpty else { return 0 }
        var total = 0
        var search = text.startIndex
        while search < text.endIndex, let range = text.range(of: q, options: .caseInsensitive, range: search..<text.endIndex) {
            total += 1
            guard range.lowerBound < range.upperBound else {
                guard range.upperBound < text.endIndex else { break }
                search = text.index(after: range.upperBound)
                continue
            }
            search = range.upperBound
        }
        return total
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
