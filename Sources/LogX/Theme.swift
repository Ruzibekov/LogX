import SwiftUI
import LogXCore

enum LogXTheme {
    static let bg = Color(red: 0.078, green: 0.071, blue: 0.063)
    static let panel = Color(red: 0.110, green: 0.098, blue: 0.090)
    static let line = Color(red: 0.247, green: 0.227, blue: 0.204)
    static let text = Color(red: 0.961, green: 0.941, blue: 0.910)
    static let muted = Color(red: 0.639, green: 0.604, blue: 0.549)
    static let ember = Color(red: 0.878, green: 0.478, blue: 0.239)
    static let ok = Color(red: 0.290, green: 0.871, blue: 0.502)
    static let warn = Color(red: 0.984, green: 0.749, blue: 0.141)
    static let err = Color(red: 0.984, green: 0.443, blue: 0.522)
    static let method = Color(red: 0.475, green: 0.753, blue: 1.0)
    static let select = Color(red: 0.165, green: 0.129, blue: 0.110)

    static func status(_ cls: LogXCore.StatusClass) -> Color {
        switch cls {
        case .ok2xx: return ok
        case .err4xx: return warn
        case .err5xx: return err
        case .net: return muted
        case .all: return text
        }
    }
}
