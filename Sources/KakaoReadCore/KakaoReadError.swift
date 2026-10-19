public let usageText = """
사용법:
  kakao-read list
  kakao-read messages --room <방 이름> (--count N | --since 24h|90m|2d|today)
"""

public enum KakaoReadError: Error, Equatable {
    case usage(String)
    case noPermission
    case notRunning
    case noListWindow
    case notChatTab
    case roomNotFound([Room])
    case ambiguousRoom([Room])
    case openFailed(String)
    case uiChanged

    public var exitCode: Int32 {
        switch self {
        case .usage, .openFailed: return 1
        case .noPermission: return 2
        case .notRunning: return 3
        case .noListWindow, .notChatTab: return 4
        case .roomNotFound, .ambiguousRoom: return 5
        case .uiChanged: return 6
        }
    }

    public var message: String {
        switch self {
        case .usage(let text):
            return text
        case .noPermission:
            return "접근성 권한이 없습니다. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 이 터미널 앱을 허용한 뒤 앱을 재시작해 주세요."
        case .notRunning:
            return "카카오톡이 실행 중이 아닙니다. 카카오톡을 실행해 주세요."
        case .noListWindow:
            return "카카오톡 채팅 목록 창을 찾을 수 없습니다. 카카오톡 잠금을 풀거나 로그인해 주세요."
        case .notChatTab:
            return "카카오톡 메인 창이 채팅 탭이 아닙니다. 메인 창에서 채팅 탭(⌘2)을 선택한 뒤 다시 시도해 주세요."
        case .roomNotFound:
            return "채팅방을 찾지 못했습니다. stdout의 목록에서 방 이름을 확인해 주세요. 조용한 채팅방 폴더 안의 방은 카톡에서 직접 열어 둔 뒤 다시 시도해 주세요."
        case .ambiguousRoom:
            return "일치하는 채팅방이 여러 개입니다. stdout의 후보 중 하나를 정확한 이름으로 지정해 주세요."
        case .openFailed(let name):
            return "채팅방 '\(name)'을(를) 열지 못했습니다. 카톡에서 직접 열어 둔 뒤 다시 시도해 주세요."
        case .uiChanged:
            return "카카오톡 화면 구조가 바뀐 것 같습니다. `kakao-read dump` 결과를 확인해 주세요."
        }
    }

    public var candidates: [Room]? {
        switch self {
        case .roomNotFound(let rooms), .ambiguousRoom(let rooms): return rooms
        default: return nil
        }
    }
}
