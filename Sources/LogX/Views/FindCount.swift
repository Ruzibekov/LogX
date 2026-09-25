import Foundation
import LogXCore

struct FindCount: Equatable {
    var contentID: String
    var query: String
    var value: Int

    static func snapshot(from cache: RenderedBody?, for key: RenderedBody.Key) -> FindCount? {
        guard let cache, cache.key.contentID == key.contentID else { return nil }
        let value = cache.key.query == key.query ? cache.matchCount : JSONFind.count(cache.attributed.string, query: key.query)
        return FindCount(contentID: key.contentID, query: key.query, value: value)
    }

    static func display(rendered: RenderedBody?, snapshot: FindCount?, query: String) -> Int {
        guard let rendered else { return 0 }
        if rendered.key.query == query { return rendered.matchCount }
        guard let snapshot, snapshot.query == query, snapshot.contentID == rendered.key.contentID else {
            return rendered.matchCount
        }
        return snapshot.value
    }
}
