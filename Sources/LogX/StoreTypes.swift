import Foundation
import LogXCore

@MainActor
final class RowHover: ObservableObject {
    @Published var key: String?

    func update(_ rowKey: String, inside: Bool) {
        if inside {
            key = rowKey
        } else {
            release(rowKey)
        }
    }

    func release(_ rowKey: String) {
        if key == rowKey { key = nil }
    }
}

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
