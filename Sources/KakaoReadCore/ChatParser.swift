import CoreGraphics
import Foundation

/// 채팅방 창 스냅샷 → 메시지 목록 (오래된 것 → 최신). 스펙 §4.1–4.2.
public enum ChatParser {
    public static func rows(in window: AXNode) -> [AXNode] {
        window.first(role: "AXTable")?.children.filter { $0.role == "AXRow" } ?? []
    }

    public static func parse(window: AXNode) -> [Message] {
        parse(rows: rows(in: window), windowFrame: window.frame)
    }

    public static func parse(rows: [AXNode], windowFrame: CGRect?) -> [Message] {
        var out: [Message] = []
        var lastOther: String? = nil
        for row in rows {
            guard let raw = classify(row, windowFrame: windowFrame) else { continue }
            switch raw {
            case .system(let text):
                out.append(Message(date: "", time: nil, sender: Message.systemSender, kind: .system, text: text))
            case .message(let date, let time, let name, let isMine, let kind, let text):
                let sender: String?
                if isMine {
                    sender = Message.me
                    lastOther = nil
                } else if let name {
                    sender = name
                    lastOther = name
                } else {
                    sender = lastOther
                }
                out.append(Message(date: date, time: time, sender: sender, kind: kind, text: text))
            }
        }
        backfillTimes(&out)
        fillSystemDates(&out)
        return out
    }

    private enum RawRow {
        case system(String)
        case message(date: String, time: String?, name: String?, isMine: Bool, kind: Message.Kind, text: String)
    }

    private static func classify(_ row: AXNode, windowFrame: CGRect?) -> RawRow? {
        let cell = row.first(role: "AXCell") ?? row
        let items = cell.children
        let bodyNode = cell.first(role: "AXTextArea")
        let body = (bodyNode?.value ?? "")
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = items.first { $0.role == "AXStaticText" && KakaoFormat.isoDate(fromHelp: $0.help ?? "") != nil }

        guard let meta, let date = KakaoFormat.isoDate(fromHelp: meta.help ?? "") else {
            let text = body.isEmpty
                ? items.filter { $0.role == "AXStaticText" }.compactMap(\.value).joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                : body
            return text.isEmpty ? nil : .system(text)
        }

        let hasProfile = items.contains { $0.role == "AXButton" && $0.desc == "프로필" }
        let name = hasProfile
            ? items.first { $0.role == "AXStaticText" && $0.help == nil && !($0.value ?? "").isEmpty }?.value
            : nil
        let images = items.filter { $0.role == "AXImage" && !($0.desc ?? "").hasPrefix("badge") }
        // 여러 장 사진은 좌우로 나란히 놓이므로 이미지 영역 전체의 합집합으로 위치를 본다.
        let imagesFrame = images.compactMap(\.frame).reduce(into: nil as CGRect?) { acc, f in acc = acc?.union(f) ?? f }

        let kind: Message.Kind = body.isEmpty ? .media : .text
        let text: String
        if body.isEmpty {
            let label = images.compactMap(\.desc).first { !$0.isEmpty }
            text = label.map { "[사진/이모티콘: \($0)]" } ?? "[사진/이모티콘]"
        } else {
            text = body
        }
        let contentFrame = body.isEmpty ? (imagesFrame ?? bodyNode?.frame) : bodyNode?.frame
        let isMine = !hasProfile && isRightSide(contentFrame, in: windowFrame)
        return .message(date: date, time: KakaoFormat.time24(from: meta.value ?? ""), name: name,
                        isMine: isMine, kind: kind, text: text)
    }

    private static func isRightSide(_ content: CGRect?, in window: CGRect?) -> Bool {
        guard let content, let window else { return false }
        return content.midX > window.midX
    }

    /// 시각은 같은 분 묶음의 마지막 행에만 있다 → 아래에서 위로 채운다.
    private static func backfillTimes(_ messages: inout [Message]) {
        var next: String? = nil
        for i in messages.indices.reversed() where messages[i].kind != .system {
            if let t = messages[i].time { next = t } else { messages[i].time = next }
        }
    }

    /// system 행 날짜: 바로 다음 메시지 날짜, 없으면 바로 앞 메시지 날짜.
    private static func fillSystemDates(_ messages: inout [Message]) {
        var next: String? = nil
        for i in messages.indices.reversed() {
            if messages[i].kind == .system {
                if messages[i].date.isEmpty, let next { messages[i].date = next }
            } else {
                next = messages[i].date
            }
        }
        var previous: String? = nil
        for i in messages.indices {
            if messages[i].kind == .system {
                if messages[i].date.isEmpty, let previous { messages[i].date = previous }
            } else {
                previous = messages[i].date
            }
        }
    }
}
