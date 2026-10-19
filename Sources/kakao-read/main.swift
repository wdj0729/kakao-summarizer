import ApplicationServices
import Foundation
import KakaoReadCore

func writeErr(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

func cmdDump(_ argv: [String]) throws {
    let app = try KakaoApp.connect()
    let only = argv.count >= 2 && argv[0] == "--window" ? argv[1] : nil
    for w in app.windows() where only == nil || AX.string(w, kAXTitleAttribute) == only {
        AX.snapshot(w).dumpLines().forEach { print($0) }
    }
}

func cmdDebug(_ argv: [String]) throws {
    let app = try KakaoApp.connect()
    switch (argv.first, argv.count) {
    case ("actions", 2):
        for row in try app.listRows() where KakaoApp.rowName(AX.snapshot(row, maxDepth: 3)) == argv[1] {
            print("row:", AX.actions(row))
            for child in AX.children(row) { print("  \(AX.role(child) ?? "?"):", AX.actions(child)) }
        }
    case ("open", 2):
        print("opened via", try app.openRoom(named: argv[1]).method)
    case ("scroll", 3):
        guard let w = app.chatWindows().first(where: { $0.title == argv[1] })?.element, let delta = Double(argv[2]) else {
            throw KakaoReadError.usage("kakao-read debug scroll <열린 채팅방 창 제목> <delta>")
        }
        func state() -> String {
            let rows = AX.snapshot(w).first(role: "AXTable")?.children.filter { $0.role == "AXRow" } ?? []
            let firstText = rows.lazy.compactMap { $0.first(role: "AXTextArea")?.value }.first ?? "-"
            return "bar=\(app.scrollBarValue(w).map { String(format: "%.4f", $0) } ?? "nil") rows=\(rows.count) first=\(firstText.prefix(20))"
        }
        print("before:", state())
        try app.scroll(w, by: delta)
        print("after: ", state())
    default:
        throw KakaoReadError.usage("kakao-read debug (actions <방> | open <방> | scroll <창 제목> <delta>)")
    }
}

let argv = Array(CommandLine.arguments.dropFirst())
do {
    switch argv.first {
    case "dump": try cmdDump(Array(argv.dropFirst()))
    case "debug": try cmdDebug(Array(argv.dropFirst()))
    default: throw KakaoReadError.usage(usageText)
    }
} catch let error as KakaoReadError {
    writeErr(error.message)
    exit(error.exitCode)
} catch {
    writeErr("\(error)")
    exit(1)
}
