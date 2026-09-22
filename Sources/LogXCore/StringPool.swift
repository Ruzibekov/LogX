import Foundation
import os

public final class StringPool: @unchecked Sendable {
    public static let shared = StringPool()
    public static let inlineCapacity = 15
    public static let limit = 8192

    private var pool: Set<String> = []
    private var lock = os_unfair_lock()

    public init() {}

    public func intern(_ value: String) -> String {
        guard value.utf8.count > StringPool.inlineCapacity else { return value }
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if let existing = pool.firstIndex(of: value) { return pool[existing] }
        guard pool.count < StringPool.limit else { return value }
        pool.insert(value)
        return value
    }

    public func intern(_ value: String?) -> String? {
        guard let value else { return nil }
        return intern(value)
    }

    public var count: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return pool.count
    }
}
