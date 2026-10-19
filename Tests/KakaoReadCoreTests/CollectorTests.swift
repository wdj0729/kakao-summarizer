import Foundation
import Testing
@testable import KakaoReadCore

/// 전체 대화 중 view개 행만 보이는 가짜 채팅 창. scroll(1.0) = rowsPerUnit 행.
final class FakeChat {
    let history: [Message]
    let view: Int
    var top: Int
    let rowsPerUnit: Double
    var scrolls = 0

    init(_ history: [Message], view: Int, startTop: Int? = nil, rowsPerUnit: Double = 100) {
        self.history = history
        self.view = view
        self.top = startTop ?? max(0, history.count - view)
        self.rowsPerUnit = rowsPerUnit
    }

    func scroll(_ delta: Double) {
        scrolls += 1
        let moved = top + Int((delta * rowsPerUnit).rounded())
        top = min(max(0, moved), max(0, history.count - view))
    }

    /// 창 맨 위 행이 이어진 메시지면 실제 카톡처럼 발신자를 알 수 없다.
    func snapshot() -> [Message] {
        var rows = Array(history[top..<min(top + view, history.count)])
        if top > 0, !rows.isEmpty { rows[0].sender = nil }
        return rows
    }

    func collector(maxScrolls: Int = 50) -> Collector {
        Collector(snapshot: { self.snapshot() }, scroll: { self.scroll($0) }, calendar: seoul, maxScrolls: maxScrolls)
    }
}

/// 실제 카톡(2026-10-19 검증): 불러온 행을 모두 유지하고, 스크롤바가 맨 위(0)에 닿을 때만 과거 행을 더 불러온다.
final class AccumulatingChat {
    let history: [Message]
    var loadedFrom: Int
    let batch: Int
    var bar = 1.0

    init(_ history: [Message], initiallyLoaded: Int, batch: Int) {
        self.history = history
        self.loadedFrom = max(0, history.count - initiallyLoaded)
        self.batch = batch
    }

    func scroll(_ delta: Double) {
        bar = min(1, max(0, bar + delta))
        if bar == 0, loadedFrom > 0 {
            loadedFrom = max(0, loadedFrom - batch)
            bar = 0.05
        }
    }

    func snapshot() -> [Message] { Array(history[loadedFrom...]) }

    func collector() -> Collector {
        Collector(snapshot: { self.snapshot() }, scroll: { self.scroll($0) }, calendar: seoul)
    }
}

func history(_ n: Int, text: (Int) -> String = { "m\($0)" }) -> [Message] {
    (0..<n).map { i in
        Message(date: "2026-10-19", time: String(format: "%02d:%02d", 9 + i / 60, i % 60),
                sender: "u\(i % 3)", kind: .text, text: text(i))
    }
}

@Suite struct CollectorTests {
    @Test func countWithinFirstView() throws {
        let fake = FakeChat(history(100), view: 30)
        let r = try fake.collector().run(until: .count(10))
        #expect(r.messages.map(\.text) == (90..<100).map { "m\($0)" })
        #expect(r.partial == nil)
    }

    @Test func countAcrossScrollsRestoresEdgeSenders() throws {
        let h = history(100)
        let r = try FakeChat(h, view: 30).collector().run(until: .count(60))
        #expect(r.messages.map(\.text) == h[40...].map(\.text))
        #expect(Array(r.messages.dropFirst()) == Array(h[41...]))
        #expect(r.partial == nil)
    }

    @Test func startsFromBottomEvenIfOpenedMidway() throws {
        let r = try FakeChat(history(100), view: 30, startTop: 20).collector().run(until: .count(5))
        #expect(r.messages.last?.text == "m99")
    }

    @Test func countReachingTopIsPartial() throws {
        let r = try FakeChat(history(40), view: 30).collector().run(until: .count(100))
        #expect(r.messages.count == 40)
        #expect(r.partial == .topReached)
    }

    @Test func sinceTrimsAtCutoff() throws {
        let cutoff = seoul.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 9, minute: 50))!
        let r = try FakeChat(history(100), view: 30).collector().run(until: .since(cutoff))
        #expect(r.messages.first?.text == "m50")
        #expect(r.messages.last?.text == "m99")
        #expect(r.partial == nil)
    }

    @Test func sinceReachingTopIsComplete() throws {
        let cutoff = seoul.date(from: DateComponents(year: 2026, month: 10, day: 18))!
        let r = try FakeChat(history(40), view: 30).collector().run(until: .since(cutoff))
        #expect(r.messages.count == 40)
        #expect(r.partial == nil)
    }

    @Test func stopsAtScrollLimit() throws {
        let r = try FakeChat(history(200), view: 20).collector(maxScrolls: 2).run(until: .count(150))
        #expect(r.messages.count == 40)
        #expect(r.partial == .scrollLimit)
    }

    @Test func halvesStepWhenScrollJumpsPastView() throws {
        let h = history(200)
        let r = try FakeChat(h, view: 20, rowsPerUnit: 1000).collector().run(until: .count(80))
        #expect(r.messages.map(\.text) == h[120...].map(\.text))
        #expect(r.partial == nil)
    }

    @Test func givesUpWhenStepTooSmall() throws {
        let r = try FakeChat(history(200), view: 20, rowsPerUnit: 1_000_000).collector().run(until: .count(80))
        #expect(r.messages.count == 20)
        #expect(r.partial == .mergeFailed)
    }

    @Test func repeatedTextsMergeCorrectly() throws {
        let h = history(100) { $0 % 10 == 0 ? "m\($0)" : "ㅋㅋ" }
        let r = try FakeChat(h, view: 30).collector().run(until: .count(60))
        #expect(r.messages.map(\.text) == h[40...].map(\.text))
        #expect(Array(r.messages.dropFirst()) == Array(h[41...]))
    }

    @Test func loadsOlderRowsOnlyAtTopWhenTableAccumulates() throws {
        let h = history(200)
        let r = try AccumulatingChat(h, initiallyLoaded: 50, batch: 20).collector().run(until: .count(120))
        #expect(r.messages.map(\.text) == h[80...].map(\.text))
        #expect(r.partial == nil)
    }

    @Test func accumulatingTableReachesTop() throws {
        let r = try AccumulatingChat(history(60), initiallyLoaded: 50, batch: 20).collector().run(until: .count(100))
        #expect(r.messages.count == 60)
        #expect(r.partial == .topReached)
    }

    @Test func overlapFindsLongestSuffixPrefix() {
        let h = history(10)
        #expect(Collector.overlap(older: Array(h[0..<6]), newer: Array(h[3..<10])) == 3)
        #expect(Collector.overlap(older: Array(h[0..<3]), newer: Array(h[5..<10])) == 0)
        #expect(Collector.overlap(older: Array(h[2..<5]), newer: Array(h[2..<10])) == 3)
        #expect(Collector.overlap(older: Array(h[0..<5]), newer: Array(h[0..<5])) == 5)
    }

    @Test func overlapIgnoresSystemDateDifferences() {
        let a = Message(date: "2026-10-18", time: nil, sender: "system", kind: .system, text: "2026년 10월 19일")
        var b = a
        b.date = "2026-10-19"
        #expect(Collector.overlap(older: [a], newer: [b]) == 1)
    }

    @Test func trimCountSkipsSystemRows() {
        var msgs = history(5)
        msgs.insert(Message(date: "2026-10-19", time: nil, sender: "system", kind: .system, text: "입장"), at: 3)
        let out = Collector.trim(msgs, to: .count(3), calendar: seoul)
        #expect(out.map(\.text) == ["m2", "입장", "m3", "m4"])
    }

    @Test func partialLabels() {
        #expect(PartialReason.topReached.label == "대화 맨 위 도달")
        #expect(PartialReason.scrollLimit.label == "스크롤 50회 상한")
        #expect(PartialReason.mergeFailed.label == "스크롤 병합 실패")
    }
}
