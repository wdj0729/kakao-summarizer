import Testing
@testable import KakaoReadCore

@Suite struct ErrorTests {
    @Test func exitCodesMatchSpec() {
        #expect(KakaoReadError.usage("x").exitCode == 1)
        #expect(KakaoReadError.openFailed("방").exitCode == 1)
        #expect(KakaoReadError.noPermission.exitCode == 2)
        #expect(KakaoReadError.notRunning.exitCode == 3)
        #expect(KakaoReadError.noListWindow.exitCode == 4)
        #expect(KakaoReadError.notChatTab.exitCode == 4)
        #expect(KakaoReadError.roomNotFound([]).exitCode == 5)
        #expect(KakaoReadError.ambiguousRoom([]).exitCode == 5)
        #expect(KakaoReadError.uiChanged.exitCode == 6)
    }

    @Test func candidatesOnlyForRoomErrors() {
        let rooms = [Room(name: "가")]
        #expect(KakaoReadError.ambiguousRoom(rooms).candidates == rooms)
        #expect(KakaoReadError.roomNotFound(rooms).candidates == rooms)
        #expect(KakaoReadError.uiChanged.candidates == nil)
    }
}
