import ApplicationServices
import Foundation
import KakaoReadCore

/// AXUIElement 읽기 헬퍼. 카톡에 쓰기(값 설정)는 KakaoApp.scroll에서만 한다.
enum AX {
    static func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(e, name as CFString, &value) == .success ? value : nil
    }

    static func string(_ e: AXUIElement, _ name: String) -> String? {
        guard let s = attr(e, name) as? String, !s.isEmpty else { return nil }
        return s
    }

    static func element(_ e: AXUIElement, _ name: String) -> AXUIElement? {
        guard let v = attr(e, name), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    static func children(_ e: AXUIElement, _ name: String = kAXChildrenAttribute) -> [AXUIElement] {
        (attr(e, name) as? [AXUIElement]) ?? []
    }

    static func frame(_ e: AXUIElement) -> CGRect? {
        guard let p = attr(e, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = attr(e, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
              AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    static func actions(_ e: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(e, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    static func perform(_ e: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(e, action as CFString) == .success
    }

    /// 너비 우선으로 조건에 맞는 첫 요소를 찾는다.
    static func find(_ root: AXUIElement, maxDepth: Int = 12, _ predicate: (AXUIElement) -> Bool) -> AXUIElement? {
        var level = [root]
        for _ in 0...maxDepth {
            if let hit = level.first(where: predicate) { return hit }
            level = level.flatMap { children($0) }
            if level.isEmpty { return nil }
        }
        return nil
    }

    static func role(_ e: AXUIElement) -> String? { string(e, kAXRoleAttribute) }

    static func snapshot(_ e: AXUIElement, depth: Int = 0, maxDepth: Int = 30) -> AXNode {
        AXNode(
            role: role(e) ?? "?",
            value: string(e, kAXValueAttribute),
            help: string(e, kAXHelpAttribute),
            desc: string(e, kAXDescriptionAttribute),
            title: string(e, kAXTitleAttribute),
            frame: frame(e),
            children: depth >= maxDepth ? [] : children(e).map { snapshot($0, depth: depth + 1, maxDepth: maxDepth) }
        )
    }
}
