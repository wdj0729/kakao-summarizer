import Foundation

/// 카톡 화면에 표시되는 날짜/시각 문자열 변환.
public enum KakaoFormat {
    private static let dateRegex = try! Regex(#"^\s*(\d{4})\.\s*(\d{1,2})\.\s*(\d{1,2})\.?\s*$"#)
    private static let timeRegex = try! Regex(#"(오전|오후)\s*(\d{1,2}):(\d{2})"#)

    /// "2026. 10. 19." → "2026-10-19"
    public static func isoDate(fromHelp s: String) -> String? {
        guard let m = s.wholeMatch(of: dateRegex),
              let y = m.output[1].substring.flatMap({ Int($0) }),
              let mo = m.output[2].substring.flatMap({ Int($0) }),
              let d = m.output[3].substring.flatMap({ Int($0) }) else { return nil }
        return String(format: "%04d-%02d-%02d", y, mo, d)
    }

    /// 문자열 안의 "오전/오후 H:MM"을 24시간제 "HH:mm"으로. 오전 12시 = 00시, 오후 12시 = 12시.
    public static func time24(from s: String) -> String? {
        guard let m = s.firstMatch(of: timeRegex),
              let ampm = m.output[1].substring,
              let h = m.output[2].substring.flatMap({ Int($0) }),
              let mi = m.output[3].substring.flatMap({ Int($0) }) else { return nil }
        let hour = h % 12 + (ampm == "오후" ? 12 : 0)
        return String(format: "%02d:%02d", hour, mi)
    }
}
