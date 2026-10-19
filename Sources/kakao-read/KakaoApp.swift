import AppKit
import ApplicationServices
import KakaoReadCore

let kakaoBundleID = "com.kakao.KakaoTalkMac"
let listWindowTitle = "카카오톡"

struct KakaoApp {
    let app: NSRunningApplication
    let root: AXUIElement

    static func connect() throws -> KakaoApp {
        guard AXIsProcessTrusted() else { throw KakaoReadError.noPermission }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: kakaoBundleID).first else {
            throw KakaoReadError.notRunning
        }
        return KakaoApp(app: app, root: AXUIElementCreateApplication(app.processIdentifier))
    }

    func windows() -> [AXUIElement] { AX.children(root, kAXWindowsAttribute) }

    func listWindow() throws -> AXUIElement {
        guard let w = windows().first(where: { AX.string($0, kAXTitleAttribute) == listWindowTitle }) else {
            throw KakaoReadError.noListWindow
        }
        return w
    }

    func chatWindows() -> [(title: String, element: AXUIElement)] {
        windows().compactMap { w in
            guard let title = AX.string(w, kAXTitleAttribute), title != listWindowTitle else { return nil }
            return (title, w)
        }
    }

    func listRows() throws -> [AXUIElement] {
        guard let table = AX.find(try listWindow(), { AX.role($0) == kAXTableRole }) else { throw KakaoReadError.uiChanged }
        return AX.children(table).filter { AX.role($0) == kAXRowRole }
    }

    /// 목록 행 스냅샷에서 방 이름(셀의 첫 AXStaticText)을 꺼낸다.
    static func rowName(_ row: AXNode) -> String? {
        (row.first(role: "AXCell") ?? row).children.first { $0.role == "AXStaticText" }?.value
    }

    func waitForChatWindow(_ name: String, timeout: TimeInterval = 2) -> AXUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let key = RoomMatcher.normalize(name)
        repeat {
            if let hit = chatWindows().first(where: { $0.title == name || RoomMatcher.normalize($0.title) == key }) {
                return hit.element
            }
            usleep(100_000)
        } while Date() < deadline
        return nil
    }

    /// 목록에서 방을 연다. AX 액션(AXOpen → AXPress, 행 → 셀) 순으로 시도하고, 모두 실패하면 더블클릭.
    /// 셀 안의 프로필 버튼에는 액션을 보내지 않는다 (프로필 창이 열림).
    func openRoom(named name: String) throws -> (window: AXUIElement, method: String) {
        if let open = waitForChatWindow(name, timeout: 0) { return (open, "already-open") }
        guard let row = try listRows().first(where: { KakaoApp.rowName(AX.snapshot($0, maxDepth: 3)) == name }) else {
            throw KakaoReadError.openFailed(name)
        }
        for target in [row] + AX.children(row) {
            let available = AX.actions(target)
            for action in ["AXOpen", kAXPressAction] where available.contains(action) {
                _ = AX.perform(target, action)
                if let w = waitForChatWindow(name) { return (w, "\(AX.role(target) ?? "?").\(action)") }
            }
        }
        // 화면 밖이나 다른 창에 가려진 좌표를 클릭하면 엉뚱한 곳이 눌린다
        // → 목록 영역 안에 있고, 그 좌표의 최상단 요소가 실제로 이 행일 때만 클릭한다.
        if let f = try visibleFrame(of: row) {
            let point = CGPoint(x: f.midX, y: f.midY)
            app.activate(options: [])
            usleep(300_000)
            guard isTopmost(row, at: point) else { throw KakaoReadError.openFailed(name) }
            Mouse.doubleClick(at: point)
            if let w = waitForChatWindow(name, timeout: 3) { return (w, "double-click") }
        }
        throw KakaoReadError.openFailed(name)
    }

    /// 창에서 AXTable을 감싼 스크롤 영역 (채팅방 메시지 목록, 메인 창 방 목록).
    func tableScrollArea(_ window: AXUIElement) -> AXUIElement? {
        AX.find(window) { e in
            AX.role(e) == kAXScrollAreaRole && AX.children(e).contains { AX.role($0) == kAXTableRole }
        }
    }

    /// 화면 좌표 point의 최상단 요소가 카톡의 target(또는 그 자손)인지.
    func isTopmost(_ target: AXUIElement, at point: CGPoint) -> Bool {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit) == .success,
              var element = hit else { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid == app.processIdentifier else { return false }
        for _ in 0..<15 {
            if CFEqual(element, target) { return true }
            guard let parent = AX.element(element, kAXParentAttribute) else { return false }
            element = parent
        }
        return false
    }

    func chatScrollBar(_ window: AXUIElement) -> AXUIElement? {
        tableScrollArea(window).flatMap { AX.element($0, kAXVerticalScrollBarAttribute) }
    }

    /// 목록 행이 스크롤 영역 안에 보이면 그 frame. 안 보이면 목록 스크롤바를 행 위치 비율로 옮겨 본 뒤 다시 확인한다.
    func visibleFrame(of row: AXUIElement) throws -> CGRect? {
        let list = try listWindow()
        guard let area = tableScrollArea(list), let areaFrame = AX.frame(area) else { return nil }
        func inside() -> CGRect? {
            guard let f = AX.frame(row), areaFrame.contains(CGPoint(x: f.midX, y: f.midY)) else { return nil }
            return f
        }
        if let f = inside() { return f }
        let rows = try listRows()
        guard let index = rows.firstIndex(where: { CFEqual($0, row) }), rows.count > 1,
              let bar = AX.element(area, kAXVerticalScrollBarAttribute) else { return nil }
        let target = Double(index) / Double(rows.count - 1)
        AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: target))
        usleep(300_000)
        return inside()
    }

    func scrollBarValue(_ window: AXUIElement) -> Double? {
        chatScrollBar(window).flatMap { (AX.attr($0, kAXValueAttribute) as? NSNumber)?.doubleValue }
    }

    /// delta: 스크롤바 비율(0…1) 변화량. 음수 = 위(과거), 양수 = 아래(최신). 이동 후 로딩을 기다린다.
    func scroll(_ window: AXUIElement, by delta: Double) throws {
        // 스크롤바는 로딩 중 잠깐 사라지거나, 메시지가 한 화면에 다 들어가는 방에는 아예 없다.
        var found = chatScrollBar(window)
        for _ in 0..<3 where found == nil {
            usleep(200_000)
            found = chatScrollBar(window)
        }
        guard let bar = found else {
            if tableScrollArea(window) != nil { return }  // 스크롤할 것이 없음 → 수집기가 맨 위 도달로 판단
            throw KakaoReadError.uiChanged
        }
        let current = (AX.attr(bar, kAXValueAttribute) as? NSNumber)?.doubleValue ?? 1
        let target = min(1, max(0, current + delta))
        let result = AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: target))
        if result != .success, let area = tableScrollArea(window), let f = AX.frame(area) {
            let point = CGPoint(x: f.midX, y: f.midY)
            if isTopmost(area, at: point) {
                Mouse.scrollWheel(at: point, pixels: Int32(-delta * 3000))
            }
        }
        usleep(400_000)
    }
}
