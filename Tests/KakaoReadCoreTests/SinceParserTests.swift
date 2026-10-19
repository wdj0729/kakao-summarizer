import Foundation
import Testing
@testable import KakaoReadCore

@Suite struct SinceParserTests {
    let now = seoul.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 12, minute: 30))!

    @Test func parsesDurations() {
        #expect(SinceParser.cutoff("24h", now: now, calendar: seoul) == now.addingTimeInterval(-24 * 3600))
        #expect(SinceParser.cutoff("90m", now: now, calendar: seoul) == now.addingTimeInterval(-90 * 60))
        #expect(SinceParser.cutoff("2d", now: now, calendar: seoul) == now.addingTimeInterval(-2 * 86400))
        #expect(SinceParser.cutoff("today", now: now, calendar: seoul) == seoul.startOfDay(for: now))
    }

    @Test func rejectsInvalid() {
        for bad in ["", "abc", "0h", "-1h", "24", "h", "1w"] {
            #expect(SinceParser.cutoff(bad, now: now, calendar: seoul) == nil, "\(bad)")
        }
    }
}
