import SwiftUI
import LogXCore

enum LogXTheme {
    static let bg = Color(red: 0.043, green: 0.051, blue: 0.078)
    static let canvas = Color(red: 0.027, green: 0.035, blue: 0.055)
    static let panel = Color(red: 0.059, green: 0.071, blue: 0.110)
    static let panel2 = Color(red: 0.086, green: 0.106, blue: 0.157)
    static let well = Color(red: 0.047, green: 0.059, blue: 0.090)
    static let line = Color(red: 0.165, green: 0.200, blue: 0.275)
    static let divider = Color(red: 0.118, green: 0.141, blue: 0.196)

    static let text = Color(red: 0.973, green: 0.980, blue: 0.988)
    static let text2 = Color(red: 0.796, green: 0.835, blue: 0.882)
    static let muted = Color(red: 0.580, green: 0.639, blue: 0.722)
    static let muted2 = Color(red: 0.392, green: 0.455, blue: 0.545)

    static let accent = Color(red: 0.388, green: 0.400, blue: 0.945)
    static let accentLight = Color(red: 0.506, green: 0.549, blue: 0.973) // #818CF8
    static let ok = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let warn = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let err = Color(red: 0.957, green: 0.247, blue: 0.369)
    static let method = Color(red: 0.220, green: 0.741, blue: 0.973)
    static let net = Color(red: 0.392, green: 0.455, blue: 0.545)
    static let ember = accent // backwards compatibility

    static func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return Color(red: 0.220, green: 0.741, blue: 0.973)
        case "POST": return Color(red: 0.063, green: 0.725, blue: 0.506)
        case "PUT": return Color(red: 0.961, green: 0.620, blue: 0.043)
        case "PATCH": return Color(red: 0.918, green: 0.702, blue: 0.031)
        case "DELETE": return Color(red: 0.957, green: 0.247, blue: 0.369)
        case "HEAD", "OPTIONS": return Color(red: 0.659, green: 0.333, blue: 0.969) // #A855F7
        default: return muted
        }
    }

    static func status(_ cls: LogXCore.StatusClass) -> Color {
        switch cls {
        case .ok2xx: return ok
        case .redirect3xx: return method
        case .err4xx: return warn
        case .err5xx: return err
        case .net: return net
        case .all: return text
        }
    }
}
