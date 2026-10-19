public struct Room: Equatable, Encodable {
    public var name: String
    public var unread: Int
    public var lastTime: String?
    public var isOpenChat: Bool
    /// 나와의 채팅(badge me). 이 방 이름이 사용자 본인 이름이다.
    public var isMe: Bool

    public init(name: String, unread: Int = 0, lastTime: String? = nil, isOpenChat: Bool = false, isMe: Bool = false) {
        self.name = name
        self.unread = unread
        self.lastTime = lastTime
        self.isOpenChat = isOpenChat
        self.isMe = isMe
    }
}
