import Testing
@testable import KakaoReadCore

@Suite struct RoomMatcherTests {
    let names = ["등산 수다방 💩", "등산 공지방 👻", "독서방", "독서방 정모"]

    func match(_ q: String) -> MatchResult<String> { RoomMatcher.match(q, in: names, name: { $0 }) }

    @Test func exactThenNormalizedThenPartial() {
        guard case .one("등산 수다방 💩") = match("등산 수다방 💩") else { Issue.record("exact"); return }
        guard case .one("등산 수다방 💩") = match("등산수다방") else { Issue.record("normalized"); return }
        guard case .one("등산 공지방 👻") = match("공지") else { Issue.record("partial"); return }
        guard case .one("독서방") = match("독서방") else { Issue.record("exact beats partial"); return }
    }

    @Test func ambiguousAndMissing() {
        guard case .many(let both) = match("등산") else { Issue.record("many"); return }
        #expect(both.count == 2)
        guard case .notFound = match("없는방") else { Issue.record("none"); return }
        guard case .notFound = match("  💩 ") else { Issue.record("empty after normalize"); return }
    }

    @Test func resolvesHiddenOpenWindow() throws {
        let rooms = [Room(name: "가족", unread: 2)]
        #expect(try TargetResolver.resolve(query: "조용한방", openChatTitles: ["조용한방"], rooms: rooms) == .openWindow("조용한방"))
    }

    @Test func prefersOpenWindowForListedRoom() throws {
        let rooms = [Room(name: "가족", unread: 2)]
        #expect(try TargetResolver.resolve(query: "가족", openChatTitles: ["가족"], rooms: rooms) == .openWindow("가족"))
        #expect(try TargetResolver.resolve(query: "가족", openChatTitles: [], rooms: rooms) == .listRoom(rooms[0]))
    }

    @Test func resolverErrors() {
        let rooms = [Room(name: "등산 수다방"), Room(name: "등산 공지방")]
        #expect(throws: KakaoReadError.ambiguousRoom(rooms)) {
            try TargetResolver.resolve(query: "등산", openChatTitles: [], rooms: rooms)
        }
        #expect(throws: KakaoReadError.roomNotFound(rooms)) {
            try TargetResolver.resolve(query: "없음", openChatTitles: [], rooms: rooms)
        }
    }
}
