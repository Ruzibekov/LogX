import Foundation

public enum DeviceBadge: Sendable {
    public static func initials(_ title: String) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "??" }
        let words = cleaned.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" })
        if words.count >= 2 {
            let first = words[0].first.map(String.init) ?? ""
            let second = words[1].first.map(String.init) ?? ""
            let pair = (first + second).uppercased()
            if pair.count == 2 { return pair }
        }
        let letters = cleaned.filter { $0.isLetter || $0.isNumber }
        guard !letters.isEmpty else { return "??" }
        return String(letters.prefix(2)).uppercased()
    }
}
