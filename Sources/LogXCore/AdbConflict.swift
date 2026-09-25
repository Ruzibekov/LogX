import Foundation

public struct AdbConflict: Equatable, Sendable, Decodable {
    public var port: Int
    public var pid: Int?
    public var serials: [String]
    public var fix: String

    public init(port: Int, pid: Int?, serials: [String], fix: String) {
        self.port = port
        self.pid = pid
        self.serials = serials
        self.fix = fix
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        port = try c.decode(Int.self, forKey: .port)
        pid = try c.decodeIfPresent(Int.self, forKey: .pid)
        serials = try c.decodeIfPresent([String].self, forKey: .serials) ?? []
        let rawFix = try c.decodeIfPresent(String.self, forKey: .fix) ?? ""
        fix = rawFix.isEmpty ? "adb -P \(port) kill-server && adb kill-server && adb devices" : rawFix
    }

    public var subtitle: String {
        let who = serials.count == 1 ? "\(serials[0]) ulangan, lekin uni" : "\(serials.count) ta qurilma ulangan, lekin ularni"
        let owner = pid.map { " (pid \($0))" } ?? ""
        return "\(who) \(port)-portdagi boshqa adb server\(owner) band qilgan. LogX 5037-portni ko'radi."
    }

    enum CodingKeys: String, CodingKey { case port, pid, serials, fix }
}
