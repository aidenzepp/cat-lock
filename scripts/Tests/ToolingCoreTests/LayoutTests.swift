import Testing
@testable import ToolingCore

struct LayoutTests {
    @Test(arguments: [
        ("func f() {\n    defer { finish() }\n    work()\n}\n", ["2:13 layout_body_lines", "2:22 layout_body_lines"]),
        (
            "var count: Int {\n    get { stored }\n    set { stored = newValue }\n}\n",
            ["2:11 layout_body_lines", "2:18 layout_body_lines", "3:11 layout_body_lines", "3:29 layout_body_lines"],
        ),
        ("var search = \"\" {\n    didSet { refresh() }\n}\n", ["2:14 layout_body_lines", "2:24 layout_body_lines"]),
        ("final class Model {\n    deinit { cancel() }\n}\n", ["2:14 layout_body_lines", "2:23 layout_body_lines"]),
        ("func f() -> Int {\n    work()\n    return 1\n}\n", ["3:5 layout_exit_blank_line"]),
        ("func f() {\n    for value in values {\n        consume(value)\n        continue\n    }\n}\n", ["4:9 layout_exit_blank_line"]),
        ("let fields = text.split(separator: \",\").map { $0 }\n", ["1:18 layout_chain_lines"]),
        ("let fields = text.split(separator: \",\")\n    .map { $0 }\n", ["1:18 layout_chain_lines"]),
        ("let titles = try store.load().get().map(\\.title)\n", ["1:23 layout_chain_lines"]),
        ("var body: some View {\n    Text(\"Title\").font(.headline)\n}\n", ["2:18 layout_chain_lines"]),
        ("func header() -> some View {\n    Text(\"Title\").font(.headline)\n}\n", ["2:18 layout_chain_lines"]),
        ("guard let index = items.firstIndex(where: { $0 > 1 }) else {\n    return\n}\n", ["1:43 layout_condition_closure"]),
        ("if values.contains(where: { $0 > 1 }) {\n    work()\n}\n", ["1:27 layout_condition_closure"]),
        ("while queue.contains(where: { $0.isReady }) {\n    work()\n}\n", ["1:29 layout_condition_closure"]),
    ])
    func `each rule reports where its fix belongs`(source: String, expected: [String]) throws {
        #expect(try findings(in: source) == expected)
    }

    @Test(arguments: [
        "func f() {\n    defer {\n        finish()\n    }\n    work()\n}\n",
        "func f() -> Int {\n    work()\n\n    return 1\n}\n",
        "func f() -> Int {\n    return 1\n}\n",
        "let fields = text\n    .split(separator: \",\")\n    .map { $0 }\n",
        "let value = try load().get()\n",
        "let files = try tooling.fix([file.path]).get()\n",
        "#expect(try tooling.sources([path]).get() == [path])\n",
        "let release = JSONDecoder().decode(Release.self, from: data)\n",
        "let percentage = Percentage.make(number).mapError { $0 }\n",
        "let result = Result { 1 }.mapError { $0 }\n",
        "let removal = FileManager.default.removeItem(at: url)\n",
        "let title = notes.first?.title.uppercased()\n",
        "func header() -> Text {\n    Text(\"Title\").font(.headline)\n}\n",
        "let label = \"\\(notes.map(\\.title).joined())\"\n",
        "let index = items.firstIndex { $0 > 1 }\nguard let index else {\n    return\n}\n",
        "guard text.hasPrefix(\"{\") else {\n    return\n}\n",
    ])
    func `conforming layouts and the approved exceptions report nothing`(source: String) throws {
        #expect(try findings(in: source).isEmpty)
    }

    @Test(arguments: [
        "func f() -> Int {\n    defer { finish() }\n    let fields = text.split(separator: \",\").map { $0 }\n    work(fields)\n    return fields.count\n}\n",
        "var body: some View {\n    VStack { Text(\"Title\").font(.headline) }.padding()\n}\n",
        "func f() {\n    work()\n    // Stop before the queue drains.\n    return\n}\n",
    ])
    func `fixing adds only line breaks and leaves nothing to fix`(source: String) throws {
        let fixed = try Layout.fixed(source).get()
        #expect(fixed.filter {
            !$0.isNewline
        } == source.filter {
            !$0.isNewline
        })
        #expect(try findings(in: fixed).isEmpty)
        #expect(try Layout.fixed(fixed).get() == fixed)
    }

    @Test
    func `a blank line goes above the comment that explains an exit`() throws {
        let source = "func f() {\n    work()\n    // Stop before the queue drains.\n    return\n}\n"
        let fixed = try Layout.fixed(source).get()
        #expect(fixed == "func f() {\n    work()\n\n    // Stop before the queue drains.\n    return\n}\n")
    }

    @Test
    func `fixing keeps CRLF line endings`() throws {
        let fixed = try Layout.fixed("func f() -> Int {\r\n    work()\r\n    return 1\r\n}\r\n").get()
        #expect(fixed == "func f() -> Int {\r\n    work()\r\n\r\n    return 1\r\n}\r\n")
    }

    @Test
    func `malformed source is refused without edits`() {
        guard case .failure = Layout.fixed("func broken( {") else {
            Issue.record("Malformed source must return a failure without edits.")

            return
        }
    }

    /// Returns each diagnostic as `line:column rule`, the parts a test asserts.
    private func findings(in source: String) throws -> [String] {
        try Layout
            .diagnostics(source, file: "Sample.swift")
            .get()
            .map { diagnostic in
                let location = diagnostic
                    .split(separator: ":")
                    .dropFirst()
                    .prefix(2)
                    .joined(separator: ":")
                let rule = diagnostic
                    .split(separator: "(")
                    .last?
                    .dropLast() ?? ""

                return "\(location) \(rule)"
            }
    }
}
