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
            let alignment = Self.align(batch: batch, acc: acc)
            if !batch.isEmpty, alignment == nil {
                // 한 화면보다 많이 올라가 틈이 생겼다 → 되돌리고 간격을 절반으로.
                try scroll(step)
                scrolls += 1
                step /= 2
                if step < minStep { partial = .mergeFailed; break }
                continue
            }
            var progressed = false
            if let (offset, _) = alignment {
                // 새로 도착한 메시지(뒤쪽)도 함께 붙인다. 진전은 과거 쪽으로 넓어졌을 때만.
                acc = Self.merge(batch: batch, acc: acc, offset: offset)
                progressed = offset < 0
            }
            if progressed {
                idle = 0
                continue
            }
            // 카톡은 불러온 행을 유지하고 맨 위에 닿을 때만 과거를 더 불러온다.
            // 과거 쪽 진전이 없으면 간격을 두 배로 늘리고, 최대 간격(맨 위)에서도 없을 때만 맨 위 도달로 본다.
            if step < 1 { step = min(1, step * 2); continue }
            idle += 1
            if idle >= topPatience {
                if case .count = stop { partial = .topReached }
                break
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

    /// batch를 acc에 겹쳐 놓을 위치. offset = batch[0]이 놓이는 acc 인덱스(음수면 acc보다 과거에서 시작).
    /// 겹치는 구간이 모두 일치하는 위치 중 가장 길게 겹치는 곳. 우연한 한 줄 일치를 피하려고 최소 2줄(배치가 더 짧으면 그 길이) 겹쳐야 한다.
    public static func align(batch: [Message], acc: [Message]) -> (offset: Int, length: Int)? {
        let b = batch.map(key)
        let a = acc.map(key)
        guard !b.isEmpty, !a.isEmpty else { return nil }
        let minLength = min(2, b.count, a.count)
        var best: (offset: Int, length: Int)? = nil
        for d in (-(b.count - 1))..<a.count {
            let start = max(0, d)
            let end = min(a.count, d + b.count)
            let length = end - start
            guard length >= minLength, length > (best?.length ?? 0) else { continue }
            if (start..<end).allSatisfy({ a[$0] == b[$0 - d] }) { best = (d, length) }
        }
        return best
    }

    /// batch를 offset 위치에 겹쳐 acc를 넓힌다: 앞쪽(과거)과 뒤쪽(새로 도착) 모두 붙이고, 겹친 구간의 빈 발신자·시각은 batch로 보충.
    public static func merge(batch: [Message], acc: [Message], offset d: Int) -> [Message] {
        var middle = acc
        for i in max(0, d)..<min(acc.count, d + batch.count) {
            let b = batch[i - d]
            if middle[i].sender == nil { middle[i].sender = b.sender }
            if middle[i].time == nil { middle[i].time = b.time }
        }
        let older = d < 0 ? Array(batch[0..<(-d)]) : []
        let newer = d + batch.count > acc.count ? Array(batch[(acc.count - d)...]) : []
        return older + middle + newer
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
