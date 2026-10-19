import Foundation
import Testing
@testable import KakaoReadCore

@Suite struct ChatParserTests {
    func parse(_ rows: [AXNode]) -> [Message] { ChatParser.parse(window: Fx.chatWindow(rows)) }

    @Test func inheritsSenderAndBackfillsTime() {
        let out = parse([
            Fx.row([Fx.profile(), Fx.meta(), Fx.name("가"), Fx.image(), Fx.body("a1")]),
            Fx.row([Fx.meta(time: "오전 11:51"), Fx.image(), Fx.body("a2")]),
            Fx.row([Fx.profile(), Fx.meta(unread: nil, time: "오전 11:52"), Fx.name("나비"), Fx.body("b1")]),
        ])
        #expect(out == [
            Message(date: "2026-10-19", time: "11:51", sender: "가", kind: .text, text: "a1"),
            Message(date: "2026-10-19", time: "11:51", sender: "가", kind: .text, text: "a2"),
            Message(date: "2026-10-19", time: "11:52", sender: "나비", kind: .text, text: "b1"),
        ])
    }

    @Test func detectsMineByHorizontalPosition() {
        let out = parse([
            Fx.row([Fx.profile(), Fx.meta(time: "오전 9:00"), Fx.name("가"), Fx.body("hi")]),
            Fx.row([Fx.meta(time: "오전 9:01"), Fx.body("내 답장", mine: true)]),
            Fx.row([Fx.meta(time: "오전 9:02"), Fx.body("고아 행")]),
        ])
        #expect(out.map(\.sender) == ["가", Message.me, nil])
    }

    @Test func mediaRowsUseLabelAndIgnoreBadges() {
        let out = parse([
            Fx.row([Fx.profile(), Fx.meta(time: "오전 9:00"), Fx.image("badge openchat profile"), Fx.name("가"), Fx.image()]),
            Fx.row([Fx.meta(time: "오전 9:01"), Fx.image("움짤", size: 80)]),
            Fx.row([Fx.meta(time: "오전 9:02"), Fx.body("\u{FFFC}")]),
            Fx.row([Fx.meta(time: "오전 9:03"), Fx.image(mine: true, size: 120)]),
        ])
        #expect(out.map(\.kind) == [.media, .media, .media, .media])
        #expect(out.map(\.text) == ["[사진/이모티콘]", "[사진/이모티콘: 움짤]", "[사진/이모티콘]", "[사진/이모티콘]"])
        #expect(out.map(\.sender) == ["가", "가", "가", Message.me])
    }

    /// 실제 카톡: 여러 장 사진은 좌우로 나란히 놓인다. 왼쪽 사진 하나만 보면 상대 메시지로 오판한다.
    @Test func multiPhotoRowUsesUnionOfImages() {
        let left = AXNode(role: "AXImage", frame: CGRect(x: 110, y: 0, width: 127, height: 127))
        let right = AXNode(role: "AXImage", frame: CGRect(x: 236, y: 0, width: 127, height: 127))
        let out = parse([Fx.row([Fx.meta(time: "오전 9:00"), left, right])])
        #expect(out.map(\.sender) == [Message.me])
    }

    /// 실제 카톡(나와의 채팅 등 안 읽은 수가 없는 방): 시각이 표시되지 않는 연속 메시지 행에는 날짜 메타가 없다.
    @Test func continuationRowsWithoutMetaAreMessages() {
        let share = AXNode(role: "AXButton", desc: "공유")
        let out = parse([
            Fx.row([share, Fx.image(mine: true, size: 120)]),
            Fx.row([share, Fx.body("링크", mine: true)]),
            Fx.row([Fx.meta(unread: nil, time: "오전 9:05"), share, Fx.body("끝", mine: true)]),
        ])
        #expect(out == [
            Message(date: "2026-10-19", time: "09:05", sender: Message.me, kind: .media, text: "[사진/이모티콘]"),
            Message(date: "2026-10-19", time: "09:05", sender: Message.me, kind: .text, text: "링크"),
            Message(date: "2026-10-19", time: "09:05", sender: Message.me, kind: .text, text: "끝"),
        ])
    }

    @Test func fileRowsBecomeMediaWithFileName() {
        let texts = ["보고서.pdf", "1.2MB", "유효기간 ~2026.11.18", "용량 1.2MB"].map {
            AXNode(role: "AXStaticText", value: $0, frame: CGRect(x: 240, y: 0, width: 120, height: 16))
        }
        let out = parse([Fx.row([Fx.meta(unread: nil, time: "오전 7:43"), AXNode(role: "AXButton", desc: "공유")] + texts + [
            AXNode(role: "AXButton", desc: "저장", title: "저장"),
        ])])
        #expect(out == [Message(date: "2026-10-19", time: "07:43", sender: Message.me, kind: .media, text: "[파일: 보고서.pdf]")])
    }

    @Test func systemRowsTakeNeighborDateAndEmptyRowsDrop() {
        let out = parse([
            Fx.row([AXNode(role: "AXButton")]),
            Fx.row([Fx.name("2026년 10월 19일 일요일")]),
            Fx.row([Fx.profile(), Fx.meta(time: "오전 9:00"), Fx.name("가"), Fx.body("hi")]),
            Fx.row([Fx.name("다님이 들어왔습니다.")]),
        ])
        #expect(out == [
            Message(date: "2026-10-19", time: nil, sender: Message.systemSender, kind: .system, text: "2026년 10월 19일 일요일"),
            Message(date: "2026-10-19", time: "09:00", sender: "가", kind: .text, text: "hi"),
            Message(date: "2026-10-19", time: nil, sender: Message.systemSender, kind: .system, text: "다님이 들어왔습니다."),
        ])
    }

    @Test func bottomEdgeTimeStaysNil() {
        let out = parse([Fx.row([Fx.profile(), Fx.meta(), Fx.name("가"), Fx.body("잘림")])])
        #expect(out.first?.time == nil)
    }

    @Test func rowsComeFromFirstTableOnly() {
        let w = Fx.chatWindow([Fx.row([Fx.meta(time: "오전 9:00"), Fx.body("x")])])
        #expect(ChatParser.rows(in: w).count == 1)
    }
}
