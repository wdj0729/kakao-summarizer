import Foundation

public enum StopCondition: Equatable {
    case count(Int)
    case since(Date)
}

public enum PartialReason: Equatable {
    case topReached, scrollLimit, mergeFailed

    public var label: String {
        switch self {
        case .topReached: return "대화 맨 위 도달"
        case .scrollLimit: return "스크롤 50회 상한"
        case .mergeFailed: return "스크롤 병합 실패"
        }
    }
}

public struct CollectResult: Equatable {
    public var messages: [Message]
    public var partial: PartialReason?
}

/// 스크롤을 위로 올리며 메시지를 모은다. 스펙 §4.4.
public struct Collector {
    public var snapshot: () throws -> [Message]
    /// 스크롤바 비율 변화량. 음수 = 위(과거).
    public var scroll: (Double) throws -> Void
    public var calendar: Calendar
    public var maxScrolls: Int
    public var initialStep: Double
    public var minStep: Double
    public var topPatience: Int

    public init(snapshot: @escaping () throws -> [Message], scroll: @escaping (Double) throws -> Void,
                calendar: Calendar = .current, maxScrolls: Int = 50, initialStep: Double = 0.1,
                minStep: Double = 0.005, topPatience: Int = 3) {
        self.snapshot = snapshot
        self.scroll = scroll
        self.calendar = calendar
        self.maxScrolls = maxScrolls
        self.initialStep = initialStep
        self.minStep = minStep
        self.topPatience = topPatience
    }

    public func run(until stop: StopCondition) throws -> CollectResult {
        // 방이 "여기까지 읽었습니다" 위치로 열릴 수 있으니 맨 아래에서 시작한다.
        try scroll(1.0)
        var acc = try snapshot()
        guard !acc.isEmpty else { return CollectResult(messages: [], partial: nil) }

        var step = initialStep
        var scrolls = 0
        var idle = 0
        var partial: PartialReason? = nil

        while !isSatisfied(acc, stop) {
            if scrolls >= maxScrolls { partial = .scrollLimit; break }
            try scroll(-step)
            scrolls += 1
            let batch = try snapshot()
            let k = Self.overlap(older: batch, newer: acc)
            if batch.isEmpty || k == batch.count {
                // 카톡은 불러온 행을 유지하고 맨 위에 닿을 때만 과거를 더 불러온다.
                // 새 행이 없으면 간격을 두 배로 늘리고, 최대 간격(맨 위)에서도 없을 때만 맨 위 도달로 본다.
                if step < 1 { step = min(1, step * 2); continue }
                idle += 1
                if idle >= topPatience {
                    if case .count = stop { partial = .topReached }
                    break
                }
            } else if k == 0 {
                // 한 화면보다 많이 올라가 틈이 생겼다 → 되돌리고 간격을 절반으로.
                try scroll(step)
                scrolls += 1
                step /= 2
                if step < minStep { partial = .mergeFailed; break }
            } else {
                acc = Self.merge(older: batch, newer: acc, overlap: k)
                idle = 0
            }
        }
        return CollectResult(messages: Self.trim(acc, to: stop, calendar: calendar), partial: partial)
    }

    private func isSatisfied(_ acc: [Message], _ stop: StopCondition) -> Bool {
        switch stop {
        case .count(let n):
            return acc.filter { $0.kind != .system }.count >= n
        case .since(let cutoff):
            guard let oldest = acc.first(where: { $0.kind != .system })?.timestamp(calendar: calendar) else { return false }
            return oldest < cutoff
        }
    }

    /// 발신자·시각은 창 가장자리에서 비어 있을 수 있어 비교하지 않는다. system 행 날짜는 이웃에서 채워져 배치마다 다를 수 있다.
    static func key(_ m: Message) -> String {
        m.kind == .system ? "system\u{1}\(m.text)" : "\(m.date)\u{1}\(m.kind.rawValue)\u{1}\(m.text)"
    }

    /// older의 뒷부분과 newer의 앞부분이 겹치는 최대 길이.
    public static func overlap(older: [Message], newer: [Message]) -> Int {
        let o = older.map(key)
        let n = newer.map(key)
        var k = min(o.count, n.count)
        while k > 0 {
            if o.suffix(k).elementsEqual(n.prefix(k)) { return k }
            k -= 1
        }
        return 0
    }

    /// 겹치는 구간은 newer 쪽을 유지하되 비어 있는 발신자·시각을 older 쪽으로 보충한다.
    public static func merge(older: [Message], newer: [Message], overlap k: Int) -> [Message] {
        var tail = newer
        for i in 0..<k {
            let o = older[older.count - k + i]
            if tail[i].sender == nil { tail[i].sender = o.sender }
            if tail[i].time == nil { tail[i].time = o.time }
        }
        return Array(older.dropLast(k)) + tail
    }

    public static func trim(_ acc: [Message], to stop: StopCondition, calendar: Calendar) -> [Message] {
        switch stop {
        case .count(let n):
            var seen = 0
            for i in acc.indices.reversed() where acc[i].kind != .system {
                seen += 1
                if seen == n { return Array(acc[i...]) }
            }
            return acc
        case .since(let cutoff):
            guard let i = acc.firstIndex(where: {
                $0.kind != .system && ($0.timestamp(calendar: calendar).map { $0 >= cutoff } ?? false)
            }) else { return [] }
            return Array(acc[i...])
        }
    }
}
