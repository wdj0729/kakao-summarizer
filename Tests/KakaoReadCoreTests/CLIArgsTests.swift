import Testing
@testable import KakaoReadCore

@Suite struct CLIArgsTests {
    @Test func parsesValidArgs() throws {
        #expect(try MessagesArgs.parse(["--room", "가족", "--count", "68"]) == MessagesArgs(room: "가족", range: .count(68)))
        #expect(try MessagesArgs.parse(["--since", "today", "--room", "가 나"]) == MessagesArgs(room: "가 나", range: .since("today")))
    }

    @Test func rejectsInvalidArgs() {
        let bad: [[String]] = [
            [], ["--room", "가족"], ["--count", "3"], ["--room", "가족", "--count", "0"],
            ["--room", "가족", "--count", "x"], ["--room", "가족", "--since", "1w"],
            ["--room", "가족", "--count", "3", "--since", "24h"], ["--room", "가족", "--count", "3", "--bogus"],
            ["--room"], ["--room", "", "--count", "3"],
        ]
        for argv in bad {
            #expect(throws: KakaoReadError.self, "\(argv)") { try MessagesArgs.parse(argv) }
        }
    }

    @Test func partialWarningText() {
        let msgs = [Message(date: "2026-10-19", time: "09:00", sender: "a", kind: .text, text: "x"),
                    Message(date: "2026-10-19", time: nil, sender: "system", kind: .system, text: "입장")]
        #expect(PartialWarning.text(result: CollectResult(messages: msgs, partial: .topReached), range: .count(68))
            == "WARN partial: 68개 요청, 1개 수집 (대화 맨 위 도달)")
        #expect(PartialWarning.text(result: CollectResult(messages: msgs, partial: .scrollLimit), range: .since("24h"))
            == "WARN partial: 24h 범위 중 1개만 수집 (스크롤 50회 상한)")
        #expect(PartialWarning.text(result: CollectResult(messages: msgs, partial: nil), range: .count(1)) == nil)
    }
}
