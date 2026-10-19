/// 메인 창(채팅 탭) 스냅샷 → 방 목록.
public enum ChatListParser {
    public static func parse(window: AXNode) throws -> [Room] {
        let isChatTab = window.children.contains { $0.role == "AXStaticText" && $0.value == "채팅" }
        guard isChatTab else { throw KakaoReadError.notChatTab }
        let rows = window.first(role: "AXTable")?.children.filter { $0.role == "AXRow" } ?? []
        return rows.compactMap(parseRow)
    }

    /// 셀의 AXStaticText 순서: 이름, [안 읽은 수], 시각. 미리보기는 AXTextArea라 제외된다.
    public static func parseRow(_ row: AXNode) -> Room? {
        let cell = row.first(role: "AXCell") ?? row
        let texts = cell.children.filter { $0.role == "AXStaticText" }.compactMap(\.value).filter { !$0.isEmpty }
        guard let name = texts.first else { return nil }
        var unread = 0
        var lastTime: String? = nil
        for t in texts.dropFirst() {
            if let n = Int(t.replacingOccurrences(of: "+", with: "")) { unread = n } else { lastTime = t }
        }
        let badges = cell.children.filter { $0.role == "AXImage" }.compactMap(\.desc)
        return Room(name: name, unread: unread, lastTime: lastTime,
                    isOpenChat: badges.contains("badge openchat room"), isMe: badges.contains("badge me"))
    }
}
