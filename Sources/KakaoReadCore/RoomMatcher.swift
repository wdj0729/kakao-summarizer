public enum MatchResult<T> {
    case one(T)
    case many([T])
    case notFound
}

public enum RoomMatcher {
    /// 소문자화하고 글자·숫자만 남긴다 (공백, 이모지, 기호 제거).
    public static func normalize(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        out.append(contentsOf: s.lowercased().unicodeScalars.filter {
            $0.properties.isAlphabetic || $0.properties.numericType != nil
        })
        return String(out)
    }

    /// 정확히 일치 → 정규화 후 일치 → 정규화 후 부분 일치. 각 단계에서 하나면 확정, 여럿이면 many.
    public static func match<T>(_ query: String, in items: [T], name: (T) -> String) -> MatchResult<T> {
        let exact = items.filter { name($0) == query }
        if let result = decide(exact) { return result }
        let q = normalize(query)
        guard !q.isEmpty else { return .notFound }
        if let result = decide(items.filter { normalize(name($0)) == q }) { return result }
        return decide(items.filter { normalize(name($0)).contains(q) }) ?? .notFound
    }

    private static func decide<T>(_ hits: [T]) -> MatchResult<T>? {
        switch hits.count {
        case 0: return nil
        case 1: return .one(hits[0])
        default: return .many(hits)
        }
    }
}

public enum Target: Equatable {
    case openWindow(String)
    case listRoom(Room)
}

public enum TargetResolver {
    /// 목록의 방과 열린 채팅방 창(목록에 안 보이는 방 포함)의 합집합에서 찾는다. 열려 있으면 그 창을 쓴다.
    public static func resolve(query: String, openChatTitles: [String], rooms: [Room]) throws -> Target {
        var candidates = rooms
        for title in openChatTitles where !rooms.contains(where: { $0.name == title }) {
            candidates.append(Room(name: title))
        }
        switch RoomMatcher.match(query, in: candidates, name: { $0.name }) {
        case .one(let room):
            return openChatTitles.contains(room.name) ? .openWindow(room.name) : .listRoom(room)
        case .many(let hits):
            throw KakaoReadError.ambiguousRoom(hits)
        case .notFound:
            throw KakaoReadError.roomNotFound(rooms)
        }
    }
}
