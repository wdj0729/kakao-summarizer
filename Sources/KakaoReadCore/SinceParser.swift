import Foundation

public enum SinceParser {
    private static let durationRegex = try! Regex(#"^(\d+)([mhd])$"#)

    /// "90m" | "24h" | "2d" | "today" → 기준 시각. 잘못된 값이나 0이면 nil.
    public static func cutoff(_ spec: String, now: Date, calendar: Calendar) -> Date? {
        if spec == "today" { return calendar.startOfDay(for: now) }
        guard let m = spec.wholeMatch(of: durationRegex),
              let n = m.output[1].substring.flatMap({ Int($0) }), n > 0,
              let unit = m.output[2].substring else { return nil }
        let seconds: Double = unit == "m" ? 60 : unit == "h" ? 3600 : 86400
        return now.addingTimeInterval(-Double(n) * seconds)
    }
}
