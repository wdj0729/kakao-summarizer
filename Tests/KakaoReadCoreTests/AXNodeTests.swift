import Foundation
import Testing
@testable import KakaoReadCore

@Suite struct AXNodeTests {
    let tree = AXNode(role: "AXWindow", title: "방", frame: CGRect(x: 0, y: 0, width: 400, height: 800), children: [
        AXNode(role: "AXScrollArea", children: [
            AXNode(role: "AXTable", children: [
                AXNode(role: "AXRow", children: [AXNode(role: "AXTextArea", value: "a\nb")]),
                AXNode(role: "AXRow", children: [AXNode(role: "AXButton", desc: "프로필")]),
            ])
        ])
    ])

    @Test func findsDescendantsDepthFirst() {
        #expect(tree.descendants { $0.role == "AXRow" }.count == 2)
        #expect(tree.first(role: "AXTextArea")?.value == "a\nb")
        #expect(tree.first(role: "AXImage") == nil)
    }

    @Test func dumpsIndentedLines() {
        #expect(tree.dumpLines() == [
            "AXWindow title=방 @(0,0 400x800)",
            "  AXScrollArea",
            "    AXTable",
            "      AXRow",
            "        AXTextArea value=a⏎b",
            "      AXRow",
            "        AXButton desc=프로필",
        ])
    }
}
