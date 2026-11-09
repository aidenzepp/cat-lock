import Foundation
import Testing
@testable import ToolingCore

/// Exercises tool behavior on owned scratch files instead of changing application code.
@Suite(.serialized)
struct ToolingTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test
    func `launcher retains an executable shebang`() throws {
        let source = try String(
            contentsOf: root.appendingPathComponent("scripts/dev.swift"),
            encoding: .utf8,
        )

        #expect(source.components(separatedBy: "\n").first == "#!/usr/bin/env swift")
    }

    @Test
    func `discovers untracked sources with spaces and excludes dependencies`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let sources = scratch.appendingPathComponent("paths with spaces")
        let dependency = sources.appendingPathComponent(".build")

        try FileManager.default.createDirectory(at: dependency, withIntermediateDirectories: true)

        let fixture = sources.appendingPathComponent("Good.swift")

        try write("struct Good {}\n", to: fixture)
        try write("struct Ignored {}\n", to: dependency.appendingPathComponent("Ignored.swift"))
        try FileManager.default.createSymbolicLink(
            at: sources.appendingPathComponent("Linked.swift"),
            withDestinationURL: fixture,
        )
        #expect(try tooling.sources([sources.path, fixture.path]).get() == [fixture.path])
        expectFailure(tooling.sources([scratch.appendingPathComponent("missing").path]))
        expectFailure(tooling.sources([dependency.path]))
    }

    @Test
    func `formatter rejects bad spacing and fix is idempotent`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("SpacingTests.swift")

        try write("func badSpacing( _ value: Int )->Int{value}\n", to: file)
        expectFailure(tooling.format([file.path]))
        try tooling.fix([file.path]).get()

        let first = try Data(contentsOf: file)

        try tooling.fix([file.path]).get()
        #expect(try Data(contentsOf: file) == first)
    }

    @Test
    func `formatter expands bodies and separates declaration groups`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("DeclarationsTests.swift")
        let compact = "struct Example {\n  static let configuration = 1\n  var repository = 2\n  mutating func run() { repository += 1 }\n}\n"

        try write(compact, to: file)
        expectFailure(tooling.format([file.path]))
        try tooling.fix([file.path]).get()

        let expected = "struct Example {\n    static let configuration = 1\n\n    var repository = 2\n\n    mutating func run() {\n        repository += 1\n    }\n}\n"

        #expect(try String(contentsOf: file, encoding: .utf8) == expected)

        let first = try Data(contentsOf: file)

        try tooling.fix([file.path]).get()
        #expect(try Data(contentsOf: file) == first)
    }

    @Test
    func `formatting keeps the blank lines an author places inside a body`() throws {
        let (tooling, scratch) = try workspace()
        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("StepLayoutTests.swift")
        let grouped = "func sample(_ ready: Bool) -> Int {\n    let value = 1\n    guard ready else {\n        return 0\n    }\n\n    consume(value)\n    if value > 1 {\n        consume(value)\n    }\n\n    return value\n}\n"
        try write(grouped, to: file)

        try tooling.format([file.path]).get()
        try tooling.fix([file.path]).get()
        #expect(try String(contentsOf: file, encoding: .utf8) == grouped)
    }

    @Test
    func `fixing applies the layout rules SwiftFormat lacks and settles them`() throws {
        let (tooling, scratch) = try workspace()
        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("LayoutRulesTests.swift")
        try write(
            "func sample(_ text: String) -> Int {\n    defer { finish() }\n    let fields = text.split(separator: \",\").map(\\.count)\n    consume(fields)\n    return fields.count\n}\n",
            to: file,
        )
        expectFailure(tooling.format([file.path]))

        try tooling.fix([file.path]).get()
        let expected = "func sample(_ text: String) -> Int {\n    defer {\n        finish()\n    }\n    let fields = text\n        .split(separator: \",\")\n        .map(\\.count)\n    consume(fields)\n\n    return fields.count\n}\n"
        #expect(try String(contentsOf: file, encoding: .utf8) == expected)

        try tooling.fix([file.path]).get()
        #expect(try String(contentsOf: file, encoding: .utf8) == expected)
    }

    @Test
    func `a closure inside a condition fails the check at its location`() throws {
        let (tooling, scratch) = try workspace()
        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("ConditionTests.swift")
        try write("func sample(_ values: [Int]) {\n    guard values.contains(where: {\n        $0 > 1\n    }) else {\n        return\n    }\n}\n", to: file)

        guard case let .failure(error) = tooling.format([file.path]) else {
            Issue.record("A closure inside a condition must fail the format check.")

            return
        }
        #expect(error.description.contains("ConditionTests.swift:2:34: error:"))
        #expect(error.description.contains("(layout_condition_closure)"))
    }

    @Test(arguments: [
        "force_unwrapping",
        "force_cast",
        "force_try",
        "unhandled_throwing_task",
        "missing_docs",
        "no_empty_block",
        "unowned_variable_capture",
        "empty_count",
        "contains_over_filter_is_empty",
        "no_discardable_result",
        "function_body_length",
    ])
    func `linter rejects unsafe code`(rule: String) throws {
        let (tooling, scratch) = try workspace()
        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("Unsafe.swift")
        try write(unsafeSource(violating: rule), to: file)

        let result = try tooling.run(
            tooling.swiftLint.path,
            [
                "lint",
                "--strict",
                "--no-cache",
                "--config",
                root.appendingPathComponent(".swiftlint.yml").path,
                file.path,
            ],
            capture: true,
        )
        .get()
        #expect(result.status != 0)
        #expect(result.output.contains(rule))
    }

    @Test(arguments: ["first_where", "last_where", "sorted_first_last", "reduce_into"])
    func `collection performance rules reject avoidable work`(rule: String) throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let expressions = [
            "first_where": ("values.filter { $0 > 0 }.first", "values.first { $0 > 0 }"),
            "last_where": ("values.filter { $0 > 0 }.last", "values.last { $0 > 0 }"),
            "sorted_first_last": ("values.sorted().first", "values.min()"),
            "reduce_into": ("values.reduce([]) { $0 + [$1] }", "values.reduce(into: []) { $0.append($1) }"),
        ]
        let pair = try #require(expressions[rule])
        let file = scratch.appendingPathComponent("PerformanceTests.swift")

        for (expression, rejected) in [(pair.0, true), (pair.1, false)] {
            try write("/// The collection result.\nlet result = \(expression)\n", to: file)

            let result = try tooling.run(tooling.swiftLint.path, [
                "lint",
                "--strict",
                "--no-cache",
                "--config",
                root.appendingPathComponent(".swiftlint.yml").path,
                file.path,
            ], capture: true)
                .get()

            #expect((result.status != 0) == rejected, "\(result.output)")
            #expect(result.output.contains("(\(rule))") == rejected)
        }
    }

    @Test
    func `multiline formatting policy expands compact layouts`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("WrappingTests.swift")
        let source = """
        func sample(first: Int,
                    second: Int, third: Int) {
            consume(first,
                    second, third)
            let result = values
                .filter { $0 > 0 }.map { $0 * 2 }
            guard ready else { return }
            Task { await work() }
            switch first {
            case 1:
                start()
                finish()
            default:
                other()
            }
        }
        """

        try write(source, to: file)
        expectFailure(tooling.format([file.path]))
        try tooling.fix([file.path]).get()

        let actual = try String(contentsOf: file, encoding: .utf8)

        #expect(actual.contains("func sample(\n    first: Int,\n    second: Int,\n    third: Int"))
        #expect(actual.contains("consume(\n        first,\n        second,\n        third"))
        #expect(actual.contains(".filter {\n            $0 > 0\n        }\n        .map {\n            $0 * 2\n        }"))
        #expect(actual.contains("guard ready else {\n        return\n    }"))
        #expect(actual.contains("Task {\n        await work()\n    }"))
        #expect(actual.contains("        finish()\n\n    default:"))
        try tooling.fix([file.path]).get()
        #expect(try String(contentsOf: file, encoding: .utf8) == actual)
    }

    @Test
    func `formatter rejects malformed swift`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("Broken.swift")

        try write("struct Broken {\n", to: file)
        expectFailure(tooling.format([file.path]))
    }

    @Test
    func `compiler accepts fixture and rejects unsafe shared state`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let arguments = [
            "swiftc",
            "-swift-version",
            "6",
            "-warnings-as-errors",
            "-strict-concurrency=complete",
            "-strict-memory-safety",
            "-typecheck",
        ]

        for source in ["Tests/ToolingFixture.swift", "scripts/dev.swift"] {
            try tooling.checked("/usr/bin/xcrun", arguments + [root.appendingPathComponent(source).path]).get()
        }

        let file = scratch.appendingPathComponent("Race.swift")

        try write("final class MutableBox: Sendable { var value = 0 }\n", to: file)

        let result = try tooling.run("/usr/bin/xcrun", arguments + [file.path], capture: true).get()

        #expect(result.status != 0)
        #expect(result.output.contains("mutable"))
    }

    @Test(arguments: ["open", "public", "package", "internal", "fileprivate", "private", "conforming", "helper"])
    func `production documentation covers every access level and conforming types`(kind: String) throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let declaration = switch kind {
        case "open":
            "open class Example {}\n"
        case "conforming":
            "struct Example: CustomStringConvertible {\n /// Describes the fixture.\n var description: String { \"example\" }\n}\n"
        case "helper":
            "private func helper() -> Int { 1 }\n"
        default:
            "\(kind) struct Example {}\n"
        }
        let file = scratch.appendingPathComponent("Production.swift")

        try write(declaration, to: file)
        expectFailure(tooling.lint([file.path]))
        try write("/// Defines the fixture contract.\n" + declaration, to: file)
        try tooling.lint([file.path]).get()
    }

    @Test
    func `documentation exception preserves safety enforcement`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let directory = scratch.appendingPathComponent("ExampleTests")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let file = directory.appendingPathComponent("Fixture.swift")

        try write("func helper(_ value: Int) -> Int { value }\n", to: file)
        try tooling.lint([file.path]).get()
        try write("func helper(_ value: Int?) -> Int { value! }\n", to: file)
        expectFailure(tooling.lint([file.path]))
    }

    @Test
    func `attribute rule ignores comments and strings`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("AttributeTests.swift")

        try write("// @discardableResult\nlet example = \"@discardableResult\"\n", to: file)
        try tooling.lint([file.path]).get()
    }

    @Test
    func `strict memory safety rejects unacknowledged pointer access`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("Unsafe.swift")

        try write("func read(_ pointer: UnsafePointer<Int>) -> Int { pointer.pointee }\n", to: file)

        let result = try tooling.run("/usr/bin/xcrun", ["swiftc", "-swift-version", "6", "-strict-memory-safety", "-warnings-as-errors", "-typecheck", file.path], capture: true).get()

        #expect(result.status != 0)
        #expect(result.output.contains("StrictMemorySafety"))
    }

    @Test
    func `checksum verification accepts the standard SHA256 abc vector`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("abc")

        try write("abc", to: file)
        try tooling.verifyArchive(file, expectedSHA256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad").get()
    }

    @Test
    func `checksum mismatch prevents installation`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let archive = scratch.appendingPathComponent("archive.zip")

        try write("not a release archive", to: archive)

        for checksum in [tooling.pins.swiftLintSHA256, tooling.pins.swiftFormatSHA256] {
            expectFailure(tooling.verifyArchive(archive, expectedSHA256: checksum))
        }
    }

    @Test
    func `failed processes and their diagnostics are preserved`() throws {
        let (tooling, scratch) = try workspace()

        defer {
            tooling.cleanup(scratch)
        }

        let result = try tooling.run(
            "/usr/bin/xcrun",
            ["--find", "nonexistent-template-tool"],
            capture: true,
        )
        .get()

        #expect(result.status != 0)
        #expect(result.output.contains("nonexistent-template-tool"))

        guard case let .failure(.command(executable, status, diagnostics)) = tooling.checked(
            "/usr/bin/xcrun",
            ["--find", "nonexistent-template-tool"],
            capture: true,
        ) else {
            Issue.record("A failed command must preserve its typed status and diagnostic output.")

            return
        }

        #expect(executable == "/usr/bin/xcrun")
        #expect(status == result.status)
        #expect(diagnostics.contains("nonexistent-template-tool"))
    }

    /// Returns a one-file source that violates the named lint rule.
    private func unsafeSource(violating rule: String) -> String {
        switch rule {
        case "force_unwrapping":
            "func unwrap(_ value: Int?) -> Int { value! }\n"
        case "force_cast":
            "func cast(_ value: Any) -> String { value as! String }\n"
        case "force_try":
            "func load() throws -> Int { 1 }\nlet result = try! load()\n"
        case "unhandled_throwing_task":
            "func load() async throws {}\nfunc start() { Task { try await load() } }\n"
        case "no_empty_block":
            "func noop() {}\n"
        case "unowned_variable_capture":
            "final class Owner { var action: (() -> Void)?; func start() { action = { [unowned self] in _ = self } } }\n"
        case "empty_count":
            "func empty(_ values: [Int]) -> Bool { values.count == 0 }\n"
        case "contains_over_filter_is_empty":
            "func empty(_ values: [Int]) -> Bool { values.filter { $0 > 0 }.isEmpty }\n"
        case "no_discardable_result":
            "@discardableResult func value() -> Int { 1 }\n"
        case "function_body_length":
            "func long() {\n" + String(repeating: "    _ = 1\n", count: 41) + "}\n"
        default:
            "public func undocumented() {}\n"
        }
    }

    private func expectFailure(
        _ result: Result<some Any, ToolingError>,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) {
        guard case .failure = result else {
            Issue.record("Expected an explicit ToolingError failure.", sourceLocation: sourceLocation)

            return
        }
    }

    private func workspace() throws -> (Tooling, URL) {
        let tooling = try Tooling.load(root: root).get()
        let scratch = root.appendingPathComponent("work/tooling-test-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        return (tooling, scratch)
    }

    private func write(_ source: String, to url: URL) throws {
        try source.write(to: url, atomically: true, encoding: .utf8)
    }
}
