import Foundation

public struct Message: Equatable, Encodable {
    public enum Kind: String, Encodable {
        case text, media, system
    }

    public static let me = "나"
    public static let unknownSender = "알 수 없음"
    public static let systemSender = "system"

    /// "yyyy-MM-dd". system 행은 파싱 직후 비어 있을 수 있다.
    public var date: String
    /// "HH:mm". 창 가장자리 행은 nil일 수 있다.
    public var time: String?
    /// 창 위쪽 가장자리의 이어진 행은 nil일 수 있다. 출력 시 "알 수 없음".
    public var sender: String?
    public var kind: Kind
    public var text: String

    public init(date: String, time: String?, sender: String?, kind: Kind, text: String) {
        self.date = date
        self.time = time
        self.sender = sender
        self.kind = kind
        self.text = text
    }

    /// date + time(없으면 00:00)을 calendar의 시간대로 해석.
    public func timestamp(calendar: Calendar) -> Date? {
        let d = date.split(separator: "-").compactMap { Int($0) }
        let t = (time ?? "00:00").split(separator: ":").compactMap { Int($0) }
        guard d.count == 3, t.count == 2 else { return nil }
        return calendar.date(from: DateComponents(year: d[0], month: d[1], day: d[2], hour: t[0], minute: t[1]))
    }

    private enum CodingKeys: String, CodingKey { case date, time, sender, kind, text }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        if let time { try c.encode(time, forKey: .time) } else { try c.encodeNil(forKey: .time) }
        try c.encode(sender ?? Message.unknownSender, forKey: .sender)
        try c.encode(kind, forKey: .kind)
        try c.encode(text, forKey: .text)
    }
}
