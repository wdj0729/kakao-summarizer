public enum RoomMatcher {
    /// 소문자화하고 글자·숫자만 남긴다 (공백, 이모지, 기호 제거).
    public static func normalize(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        out.append(contentsOf: s.lowercased().unicodeScalars.filter {
            $0.properties.isAlphabetic || $0.properties.numericType != nil
        })
        return String(out)
    }
}
