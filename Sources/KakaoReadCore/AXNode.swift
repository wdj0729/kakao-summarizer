import CoreGraphics
import Foundation

/// 접근성 트리 한 노드의 스냅샷. 카톡 없이 테스트할 수 있도록 순수 값 타입으로 둔다.
public struct AXNode: Equatable {
    public var role: String
    public var value: String?
    public var help: String?
    public var desc: String?
    public var title: String?
    public var frame: CGRect?
    public var children: [AXNode]

    public init(role: String, value: String? = nil, help: String? = nil, desc: String? = nil,
                title: String? = nil, frame: CGRect? = nil, children: [AXNode] = []) {
        self.role = role
        self.value = value
        self.help = help
        self.desc = desc
        self.title = title
        self.frame = frame
        self.children = children
    }

    /// 자기 자신을 포함해 깊이 우선으로 조건에 맞는 노드를 모은다.
    public func descendants(where predicate: (AXNode) -> Bool) -> [AXNode] {
        var out: [AXNode] = predicate(self) ? [self] : []
        for child in children { out += child.descendants(where: predicate) }
        return out
    }

    public func first(role: String) -> AXNode? {
        descendants { $0.role == role }.first
    }

    public func dumpLines(indent: Int = 0) -> [String] {
        var parts = [role]
        for (key, val) in [("title", title), ("value", value), ("desc", desc), ("help", help)] {
            if let val, !val.isEmpty { parts.append("\(key)=\(val.replacingOccurrences(of: "\n", with: "⏎"))") }
        }
        if let f = frame { parts.append("@(\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height)))") }
        let line = String(repeating: "  ", count: indent) + parts.joined(separator: " ")
        return [line] + children.flatMap { $0.dumpLines(indent: indent + 1) }
    }
}
