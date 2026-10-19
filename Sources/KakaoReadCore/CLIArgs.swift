import Foundation

public enum RangeSpec: Equatable {
    case count(Int)
    case since(String)
}

public struct MessagesArgs: Equatable {
    public var room: String
    public var range: RangeSpec

    public init(room: String, range: RangeSpec) {
        self.room = room
        self.range = range
    }

    public static func parse(_ argv: [String]) throws -> MessagesArgs {
        let usage = KakaoReadError.usage(usageText)
        var room: String? = nil
        var range: RangeSpec? = nil
        var it = argv.makeIterator()
        while let flag = it.next() {
            guard let value = it.next() else { throw usage }
            switch flag {
            case "--room":
                room = value
            case "--count":
                guard range == nil, let n = Int(value), n > 0 else { throw usage }
                range = .count(n)
            case "--since":
                guard range == nil, SinceParser.cutoff(value, now: Date(), calendar: .current) != nil else { throw usage }
                range = .since(value)
            default:
                throw usage
            }
        }
        guard let room, !room.isEmpty, let range else { throw usage }
        return MessagesArgs(room: room, range: range)
    }
}

public enum PartialWarning {
    public static func text(result: CollectResult, range: RangeSpec) -> String? {
        guard let partial = result.partial else { return nil }
        let got = result.messages.filter { $0.kind != .system }.count
        switch range {
        case .count(let n): return "WARN partial: \(n)개 요청, \(got)개 수집 (\(partial.label))"
        case .since(let spec): return "WARN partial: \(spec) 범위 중 \(got)개만 수집 (\(partial.label))"
        }
    }
}
