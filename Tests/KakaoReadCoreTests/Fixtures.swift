import Foundation
@testable import KakaoReadCore

/// 실제 카톡 AX 구조를 본뜬 가짜 데이터. 실제 이름/대화는 넣지 않는다.
enum Fx {
    static let winFrame = CGRect(x: 0, y: 0, width: 400, height: 800)

    static func meta(unread: String? = "3", time: String? = nil, date: String = "2026. 10. 19.") -> AXNode {
        AXNode(role: "AXStaticText", value: [unread, time].compactMap { $0 }.joined(separator: "\n"), help: date)
    }
    static func profile() -> AXNode { AXNode(role: "AXButton", desc: "프로필") }
    static func name(_ s: String) -> AXNode { AXNode(role: "AXStaticText", value: s) }
    static func body(_ s: String, mine: Bool = false) -> AXNode {
        AXNode(role: "AXTextArea", value: s,
               frame: CGRect(x: mine ? 260 : 60, y: 0, width: 120, height: 20))
    }
    static func image(_ desc: String? = nil, mine: Bool = false, size: CGFloat = 10) -> AXNode {
        AXNode(role: "AXImage", desc: desc, frame: CGRect(x: mine ? 300 : 60, y: 0, width: size, height: size))
    }
    static func row(_ items: [AXNode]) -> AXNode {
        AXNode(role: "AXRow", children: [AXNode(role: "AXCell", children: items)])
    }
    static func chatWindow(_ rows: [AXNode]) -> AXNode {
        AXNode(role: "AXWindow", title: "테스트방", frame: winFrame, children: [
            AXNode(role: "AXScrollArea", children: [AXNode(role: "AXTable", children: rows + [AXNode(role: "AXColumn")])]),
            AXNode(role: "AXScrollArea", children: [AXNode(role: "AXTextArea", value: "입력창")]),
        ])
    }
    static func listRow(name: String, unread: String? = nil, time: String = "오후 12:02",
                        preview: String = "미리보기", badges: [String] = []) -> AXNode {
        var items: [AXNode] = [profile()]
        items += badges.map { AXNode(role: "AXImage", desc: $0) }
        items.append(AXNode(role: "AXStaticText", value: name))
        if let unread { items.append(AXNode(role: "AXStaticText", value: unread)) }
        items.append(AXNode(role: "AXStaticText", value: time))
        items.append(AXNode(role: "AXScrollArea", children: [AXNode(role: "AXTextArea", value: preview)]))
        return row(items)
    }
    static func listWindow(tab: String = "채팅", rows: [AXNode]) -> AXNode {
        AXNode(role: "AXWindow", title: "카카오톡", children: [
            AXNode(role: "AXButton", help: "친구 (⌘1)"),
            AXNode(role: "AXStaticText", value: tab),
            AXNode(role: "AXScrollArea", children: [AXNode(role: "AXTable", children: rows)]),
        ])
    }
}
