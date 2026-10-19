import Foundation
import Testing
@testable import KakaoReadCore

let seoul: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return c
}()

@Suite struct FormatAndMessageTests {
    @Test func parsesHelpDate() {
        #expect(KakaoFormat.isoDate(fromHelp: "2026. 10. 19.") == "2026-10-19")
        #expect(KakaoFormat.isoDate(fromHelp: "2026. 1. 5.") == "2026-01-05")
        #expect(KakaoFormat.isoDate(fromHelp: "오전 11:51") == nil)
        #expect(KakaoFormat.isoDate(fromHelp: "") == nil)
    }

    @Test func extractsTimeAnywhere() {
        #expect(KakaoFormat.time24(from: "오전 11:51") == "11:51")
        #expect(KakaoFormat.time24(from: "43\n오후 3:07") == "15:07")
        #expect(KakaoFormat.time24(from: "43") == nil)
    }

    @Test func convertsNoonAndMidnight() {
        #expect(KakaoFormat.time24(from: "오전 12:05") == "00:05")
        #expect(KakaoFormat.time24(from: "오후 12:02") == "12:02")
        #expect(KakaoFormat.time24(from: "오후 11:59") == "23:59")
    }

    @Test func encodesNilsExplicitly() {
        let m = Message(date: "2026-10-19", time: nil, sender: nil, kind: .text, text: "https://a.b/c")
        #expect(JSONOutput.line(m) ==
            #"{"date":"2026-10-19","kind":"text","sender":"알 수 없음","text":"https://a.b/c","time":null}"#)
    }

    @Test func buildsTimestampInCalendarZone() {
        let m = Message(date: "2026-10-19", time: "11:51", sender: "a", kind: .text, text: "x")
        let expected = seoul.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 11, minute: 51))
        #expect(m.timestamp(calendar: seoul) == expected)
        let noTime = Message(date: "2026-10-19", time: nil, sender: "a", kind: .text, text: "x")
        #expect(noTime.timestamp(calendar: seoul) == seoul.date(from: DateComponents(year: 2026, month: 10, day: 19)))
        let noDate = Message(date: "", time: "11:51", sender: "a", kind: .system, text: "x")
        #expect(noDate.timestamp(calendar: seoul) == nil)
    }
}
