import Foundation
import Testing
@testable import ToolingCore

@Suite(.serialized)
struct PolicyTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test(arguments: [
        ("throws", "func work() throws { consume() }"),
        ("typed throws", "func work() throws(Failure) { consume() }"),
        ("rethrows", "func work(_ body: () throws -> Void) rethrows { try body() }"),
        ("catch", "func work() { do { try consume() } catch { report(error) } }"),
        ("literal unwrap", "let url = URL(string: \"https://example.com\")!"),
        ("outlet IUO", "class Controller { @IBOutlet var label: UILabel! }"),
    ])
    func `strict policy rejects previously permitted constructs`(kind: String, source: String) throws {
        let tooling = try Tooling.load(root: root).get()
        let scratch = root.appendingPathComponent("work/policy-test-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("Production.swift")

        try source.write(to: file, atomically: true, encoding: .utf8)

        let result = try tooling.run(tooling.swiftLint.path, [
            "lint",
            "--strict",
            "--no-cache",
            "--config",
            root.appendingPathComponent(".swiftlint.yml").path,
            file.path,
        ], capture: true)
            .get()
        let rule = switch kind {
        case "literal unwrap":
            "force_unwrapping"
        case "outlet IUO":
            "implicitly_unwrapped_optional"
        default:
            "result_failure_paths"
        }

        #expect(result.status != 0)
        #expect(result.output.contains("(\(rule))"), "\(result.output)")
    }

    @Test
    func `Result syntax comments and strings pass and tests may throw`() throws {
        let tooling = try Tooling.load(root: root).get()
        let scratch = root.appendingPathComponent("work/policy-test-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        defer {
            tooling.cleanup(scratch)
        }

        let sources = [
            ("Production.swift", """
            /// An error captured at the boundary.
            enum Failure: Error {
                /// An invalid SDK value.
                case invalid
            }
            /// Wraps the SDK's failure.
            func work() -> Result<Int, Failure> {
                // throws, rethrows and catch are examples, not Swift keywords here.
                Result(catching: { try sdk() }).mapError { _ in .invalid }
            }
            /// A documentation example.
            let example = "throws rethrows catch"
            """),
            ("NativeTests.swift", "func testSDK() throws { try sdk() }"),
            ("NestedTests/Helpers/Fixture.swift", "func helper() throws { try sdk() }"),
        ]

        for (path, source) in sources {
            let file = scratch.appendingPathComponent(path)

            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try source.write(to: file, atomically: true, encoding: .utf8)

            var arguments = ["lint", "--strict", "--no-cache", "--config", root.appendingPathComponent(".swiftlint.yml").path]

            if path != "Production.swift" {
                arguments += ["--config", root.appendingPathComponent(".swiftlint-tests.yml").path]
            }

            let result = try tooling.run(tooling.swiftLint.path, arguments + [file.path], capture: true).get()

            #expect(result.status == 0, "\(result.output)")
        }
    }

    @Test
    func `lint command includes the SwiftUI API currency scan`() throws {
        let tooling = try Tooling.load(root: root).get()
        let scratch = root.appendingPathComponent("work/policy-test-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("ViewTests.swift")

        try "import SwiftUI\nlet view = Text(\"Hello\").foregroundColor(.red)\n"
            .write(to: file, atomically: true, encoding: .utf8)

        guard case let .failure(error) = tooling.lint([file.path]) else {
            Issue.record("The lint command must reject soft-deprecated SwiftUI calls.")

            return
        }

        #expect(error.description.contains("soft_deprecated_swiftui"))
        try "import SwiftUI\nlet view = Text(\"Hello\").foregroundStyle(.red)\n"
            .write(to: file, atomically: true, encoding: .utf8)
        try tooling.lint([file.path]).get()
    }

    @Test
    func `bare existential is rejected while explicit any compiles`() throws {
        let tooling = try Tooling.load(root: root).get()
        let scratch = root.appendingPathComponent("work/policy-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer {
            tooling.cleanup(scratch)
        }

        let file = scratch.appendingPathComponent("Existentials.swift")
        for (type, status) in [("Description", false), ("any Description", true)] {
            try "protocol Description {}\nfunc consume(_ value: \(type)) {}\n"
                .write(to: file, atomically: true, encoding: .utf8)

            let result = try tooling.run("/usr/bin/xcrun", [
                "swiftc",
                "-swift-version",
                "6",
                "-enable-upcoming-feature",
                "ExistentialAny",
                "-warnings-as-errors",
                "-typecheck",
                file.path,
            ], capture: true)
                .get()
            #expect((result.status == 0) == status, "\(result.output)")
            if !status {
                #expect(result.output.contains("any"))
            }
        }

        try expectExistentialAnyInEveryTarget(tooling: tooling, scratch: scratch)

        let config = try String(contentsOf: root.appendingPathComponent("config/Strict.xcconfig"), encoding: .utf8)
        #expect(config.contains("SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES"))
    }

    /// Checks that every target in the tooling manifest enables the `ExistentialAny` upcoming feature.
    private func expectExistentialAnyInEveryTarget(tooling: Tooling, scratch: URL) throws {
        let dump = try tooling.output("/usr/bin/xcrun", ["swift", "package", "--package-path", "scripts", "--scratch-path", scratch.appendingPathComponent("manifest").path, "dump-package"]).get()
        let package = try #require(JSONSerialization.jsonObject(with: Data(dump.utf8)) as? [String: Any])
        let targets = try #require(package["targets"] as? [[String: Any]])
        #expect(targets.count == 3)

        for target in targets {
            let settings = try #require(target["settings"] as? [[String: Any]])
            #expect(settings.contains { setting in
                guard let kind = setting["kind"] as? [String: Any],
                      let feature = kind["enableUpcomingFeature"] as? [String: Any],
                      let name = feature["_0"] as? String
                else {
                    return false
                }

                return name == "ExistentialAny"
            })
        }
    }
}
