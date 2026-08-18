import Foundation

public struct LooseMap: Decodable {
    public var values: [String: String]

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let dict = try? c.decode([String: String].self) {
            values = dict
            return
        }
        if let any = try? c.decode([String: LooseText].self) {
            values = any.mapValues { $0.text ?? "" }
            return
        }
        values = [:]
    }
}

public struct LooseText: Decodable {
    public var text: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            text = nil
        } else if let s = try? c.decode(String.self) {
            text = s
        } else if let n = try? c.decode(Int.self) {
            text = String(n)
        } else if let obj = try? c.decode([String: LooseText].self) {
            let data = try JSONEncoder().encode(obj.mapValues { $0.text ?? "" })
            text = String(data: data, encoding: .utf8)
        } else {
            text = nil
        }
    }
}

extension LooseText: Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(text)
    }
}
