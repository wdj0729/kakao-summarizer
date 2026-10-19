import CoreGraphics

/// AX 액션이 통하지 않을 때만 쓰는 마우스 폴백. 커서가 실제로 움직인다.
enum Mouse {
    /// 호출 전에 point의 최상단 요소가 대상인지 확인할 것 (KakaoApp.isTopmost).
    static func doubleClick(at point: CGPoint) {
        for clickState in [1, 2] {
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
                event?.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
                event?.post(tap: .cghidEventTap)
            }
        }
    }

    /// pixels > 0 이면 위로(과거 쪽) 스크롤. 호출 전에 point가 대상 영역인지 확인할 것.
    static func scrollWheel(at point: CGPoint, pixels: Int32) {
        CGWarpMouseCursorPosition(point)
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: pixels, wheel2: 0, wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }
}
