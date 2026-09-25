import SwiftUI

enum MethodTone: Equatable {
    case get
    case post
    case put
    case patch
    case delete
    case other

    static func of(_ method: String) -> MethodTone {
        switch method.uppercased() {
        case "GET": return .get
        case "POST": return .post
        case "PUT": return .put
        case "PATCH": return .patch
        case "DELETE": return .delete
        default: return .other
        }
    }

    var hex: LogXHexPair {
        switch self {
        case .get: return LogXPalette.methodGet
        case .post: return LogXPalette.methodPost
        case .put: return LogXPalette.methodPut
        case .patch: return LogXPalette.methodPatch
        case .delete: return LogXPalette.methodDelete
        case .other: return LogXPalette.text2
        }
    }
}

struct MethodBadge: View {
    static let fillOpacity = 0.14
    static let edgeOpacity = 0.34

    let method: String
    var size: CGFloat = LogXType.caption
    var minWidth: CGFloat = 0

    private var tint: Color { LogXTheme.color(MethodTone.of(method).hex) }

    var body: some View {
        Text(method.uppercased())
            .font(LogXType.mono(size, .bold))
            .tracking(0.4)
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .frame(minWidth: minWidth)
            .background(tint.opacity(Self.fillOpacity), in: RoundedRectangle(cornerRadius: LogXRadius.chip, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LogXRadius.chip, style: .continuous).stroke(tint.opacity(Self.edgeOpacity), lineWidth: 1))
            .animation(LogXMotion.statusCrossfade, value: method)
            .accessibilityLabel("Metod \(method.uppercased())")
    }
}
