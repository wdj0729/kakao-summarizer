import ApplicationServices
import Foundation
import KakaoReadCore

func writeErr(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

func cmdList() throws {
    let app = try KakaoApp.connect()
    let rooms = try ChatListParser.parse(window: AX.snapshot(try app.listWindow()))
    print(JSONOutput.line(rooms))
}

func cmdMessages(_ argv: [String]) throws {
    let args = try MessagesArgs.parse(argv)
    let stop: StopCondition
    switch args.range {
    case .count(let n):
        stop = .count(n)
    case .since(let spec):
        guard let cutoff = SinceParser.cutoff(spec, now: Date(), calendar: .current) else {
            throw KakaoReadError.usage(usageText)
        }
        stop = .since(cutoff)
    }

    let app = try KakaoApp.connect()
    var rooms: [Room] = []
    var listError: KakaoReadError? = nil
    do {
        rooms = try ChatListParser.parse(window: AX.snapshot(try app.listWindow()))
    } catch let error as KakaoReadError {
        listError = error
    }
    let openWindows = app.chatWindows()
    let target: Target
    do {
        target = try TargetResolver.resolve(query: args.room, openChatTitles: openWindows.map { $0.title }, rooms: rooms)
    } catch KakaoReadError.roomNotFound(_) where listError != nil {
        throw listError!
    }

    let window: AXUIElement
    switch target {
    case .openWindow(let title):
        window = openWindows.first { $0.title == title }!.element
    case .listRoom(let room):
        window = try app.openRoom(named: room.name).window
    }

    let first = AX.snapshot(window)
    if !ChatParser.rows(in: first).isEmpty && ChatParser.parse(window: first).isEmpty {
        throw KakaoReadError.uiChanged
    }

    // KAKAO_READ_DEBUG=1: 스크롤/스냅샷마다 진단 한 줄을 stderr로 (내용 없이 개수·시각만).
    let debug = ProcessInfo.processInfo.environment["KAKAO_READ_DEBUG"] != nil
    let collector = Collector(
        snapshot: {
            let snap = AX.snapshot(window)
            let batch = ChatParser.parse(window: snap)
            if debug {
                let times = batch.compactMap { $0.time }
                writeErr("DEBUG snapshot rows=\(ChatParser.rows(in: snap).count) msgs=\(batch.count) \(times.first ?? "-")…\(times.last ?? "-") bar=\(app.scrollBarValue(window).map { String(format: "%.4f", $0) } ?? "nil")")
            }
            return batch
        },
        scroll: { delta in
            if debug { writeErr("DEBUG scroll \(delta)") }
            try app.scroll(window, by: delta)
        })
    let result = try collector.run(until: stop)
    for message in result.messages { print(JSONOutput.line(message)) }
    if let warning = PartialWarning.text(result: result, range: args.range) { writeErr(warning) }
}

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
    case "list": try cmdList()
    case "messages": try cmdMessages(Array(argv.dropFirst()))
    case "dump": try cmdDump(Array(argv.dropFirst()))
    case "debug": try cmdDebug(Array(argv.dropFirst()))
    default: throw KakaoReadError.usage(usageText)
    }
} catch let error as KakaoReadError {
    if let candidates = error.candidates { print(JSONOutput.line(candidates)) }
    writeErr(error.message)
    exit(error.exitCode)
} catch {
    writeErr("\(error)")
    exit(1)
}
