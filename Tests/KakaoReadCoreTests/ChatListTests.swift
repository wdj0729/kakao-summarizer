import Testing
@testable import KakaoReadCore

@Suite struct ChatListTests {
    @Test func parsesRoomsWithBadges() throws {
        let w = Fx.listWindow(rows: [
            Fx.listRow(name: "등산 모임 ⛰️", unread: "68", time: "오후 12:02", badges: ["badge openchat room"]),
            Fx.listRow(name: "가족", time: "오전 9:23"),
            Fx.listRow(name: "홍길동", time: "10월 13일", badges: ["badge me"]),
        ])
        #expect(try ChatListParser.parse(window: w) == [
            Room(name: "등산 모임 ⛰️", unread: 68, lastTime: "오후 12:02", isOpenChat: true),
            Room(name: "가족", unread: 0, lastTime: "오전 9:23"),
            Room(name: "홍길동", unread: 0, lastTime: "10월 13일", isMe: true),
        ])
    }

    @Test func parsesUnreadOverflowAndRelativeTimes() throws {
        let w = Fx.listWindow(rows: [
            Fx.listRow(name: "큰방", unread: "999+", time: "어제"),
            Fx.listRow(name: "작은방", unread: "7", time: "10월 17일"),
        ])
        let rooms = try ChatListParser.parse(window: w)
        #expect(rooms.map(\.unread) == [999, 7])
        #expect(rooms.map(\.lastTime) == ["어제", "10월 17일"])
    }

    @Test func rejectsNonChatTab() {
        let w = Fx.listWindow(tab: "친구", rows: [Fx.listRow(name: "친구1")])
        #expect(throws: KakaoReadError.notChatTab) { try ChatListParser.parse(window: w) }
    }

    @Test func skipsRowsWithoutText() throws {
        let w = Fx.listWindow(rows: [Fx.row([AXNode(role: "AXButton")]), Fx.listRow(name: "가족")])
        #expect(try ChatListParser.parse(window: w).map(\.name) == ["가족"])
    }
}
