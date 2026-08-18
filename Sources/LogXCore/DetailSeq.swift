import Foundation

public struct DetailSeq: Equatable, Sendable {
    public private(set) var value = 0

    public init() {}

    public mutating func next() -> Int {
        value += 1
        return value
    }

    public func isCurrent(_ token: Int) -> Bool {
        token == value
    }
}
