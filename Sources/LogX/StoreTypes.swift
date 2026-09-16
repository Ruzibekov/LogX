import Foundation
import LogXCore

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var actionTitle: String?
    var action: (() -> Void)?

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// Solishtirish oynasi uchun juftlik: A — belgilangan (eski), B — joriy.
struct DiffPair: Identifiable, Equatable {
    var a: NetworkLog
    var b: NetworkLog

    var id: String { a.key + "|" + b.key }
}

public enum LogSortField: String, CaseIterable, Equatable {
    case time
    case method
    case status
    case duration
    case path
}

public enum SortOrder: Equatable {
    case ascending
    case descending
}
