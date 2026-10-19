import AppKit
import CoreGraphics

/// AX 액션이 통하지 않을 때만 쓰는 마우스 폴백. 커서가 실제로 움직인다.
enum Mouse {
    static func doubleClick(at point: CGPoint, app: NSRunningApplication) {
        app.activate(options: [])
        usleep(300_000)
        for clickState in [1, 2] {
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
                event?.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
                event?.post(tap: .cghidEventTap)
            }
        }
    }

    /// pixels > 0 이면 위로(과거 쪽) 스크롤.
    static func scrollWheel(at point: CGPoint, pixels: Int32) {
        CGWarpMouseCursorPosition(point)
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: pixels, wheel2: 0, wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }
}
