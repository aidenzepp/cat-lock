import CryptoKit
import Foundation

/// The versions and release checksum shared by setup, diagnostics, and CI.
package struct Toolchain: Codable {
    /// The required Xcode release selected for builds.
    package let xcodeVersion: String
    /// The exact Apple build identifier, including patch-build identity.
    package let xcodeBuild: String
    /// The SwiftLint release installed inside this repository.
    package let swiftLintVersion: String
    /// The expected SHA-256 of the SwiftLint release archive.
    package let swiftLintSHA256: String
    /// The SwiftFormat release that owns the formatting policy.
    package let swiftFormatVersion: String
    /// The expected SHA-256 of the SwiftFormat release archive.
    package let swiftFormatSHA256: String
}

/// A pinned upstream tool archive and its executable version interface.
private struct ToolRelease {
    /// The executable name and repository-local installation namespace.
    let name: String
    /// The upstream release version required by the tool pin.
    let version: String
    /// The archive checksum required before extraction or execution.
    let sha256: String
    /// The pinned upstream release asset URL.
    let downloadURL: String
    /// The arguments that print only the executable release version.
    let versionArguments: [String]
}

/// A child process's termination status and, when requested, combined diagnostics.
package struct CommandResult {
    /// The child exit status; zero denotes successful completion.
    package let status: Int32
    /// Combined captured diagnostics, or an empty string when streams are inherited.
    package let output: String
}

/// A failed tool invocation or an actionable configuration problem.
package enum ToolingError: Error, CustomStringConvertible {
    /// An actionable configuration or source-selection failure.
    case invalid(String)
    /// A failed child command with its status and captured diagnostics.
    case command(String, Int32, String)

    /// A diagnostic preserving the failed operation and its underlying details.
    package var description: String {
        switch self {
        case let .invalid(message):
            message
        case let .command(executable, status, output):
            "\(executable) exited with status \(status).\(output.isEmpty ? "" : "\n" + output)"
        }
    }

    /// Keeps typed tool failures intact and maps Foundation failures to visible diagnostics.
    package static func from(_ error: any Error) -> ToolingError {
        (error as? ToolingError) ?? .invalid(String(describing: error))
    }
}

/// Runs repository tooling using explicit arguments, the pinned toolchain, and local tools.
package struct Tooling {
    /// Directory names the source commands never enter: tools, dependencies, build output and local research.
    private static let excludedDirectories: Set = [
        ".git",
        ".tools",
        ".vivi",
        "work",
        ".build",
        ".swiftpm",
        "DerivedData",
        "build",
        "vendor",
        "node_modules",
        "Pods",
        "Carthage",
    ]

    /// The checkout whose configuration and local tools this instance owns.
    package let root: URL
    /// The decoded release identities and archive checksums for this checkout.
    package let pins: Toolchain

    /// The invocation directory used to resolve explicit relative source paths.
    private let callerDirectory: URL

    /// The pinned local linter executable, without a global fallback.
    package var swiftLint: URL {
        binary(for: swiftLintRelease)
    }

    /// The pinned local formatter executable, without a global fallback.
    package var swiftFormat: URL {
        binary(for: swiftFormatRelease)
    }

    /// The linter release asset and executable version interface.
    private var swiftLintRelease: ToolRelease {
        ToolRelease(
            name: "swiftlint",
            version: pins.swiftLintVersion,
            sha256: pins.swiftLintSHA256,
            downloadURL: "https://github.com/realm/SwiftLint/releases/download/\(pins.swiftLintVersion)/portable_swiftlint.zip",
            versionArguments: ["version"],
        )
    }

    /// The formatter release asset and executable version interface.
    private var swiftFormatRelease: ToolRelease {
        ToolRelease(
            name: "swiftformat",
            version: pins.swiftFormatVersion,
            sha256: pins.swiftFormatSHA256,
            downloadURL: "https://github.com/nicklockwood/SwiftFormat/releases/download/\(pins.swiftFormatVersion)/swiftformat.zip",
            versionArguments: ["--version"],
        )
    }

    /// Loads pins from the selected template; relative source paths retain caller semantics.
    package static func load(root: URL) -> Result<Tooling, ToolingError> {
        Result(catching: {
            let pins = try JSONDecoder().decode(
                Toolchain.self,
                from: Data(contentsOf: root.appendingPathComponent("toolchain.json")),
            )

            return Tooling(
                root: root.standardizedFileURL,
                pins: pins,
                callerDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            )
        }).mapError(ToolingError.from)
    }

    /// Launches without a shell, draining combined output before waiting to avoid pipe deadlocks.
    package func run(
        _ executable: String,
        _ arguments: [String],
        capture: Bool = false,
    ) -> Result<CommandResult, ToolingError> {
        Result(catching: {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = root

            var environment = ProcessInfo.processInfo.environment

            environment["TOOLCHAINS"] = "com.apple.dt.toolchain.XcodeDefault"
            process.environment = environment

            let pipe = capture ? Pipe() : nil

            if let pipe {
                process.standardOutput = pipe
                process.standardError = pipe
            }

            try process.run()

            let data = pipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()

            process.waitUntilExit()

            return CommandResult(
                status: process.terminationStatus,
                output: String(decoding: data, as: UTF8.self),
            )
        }).mapError(ToolingError.from)
    }

    /// Executes an effectful command and rejects failure without exposing an ignorable result.
    package func checked(
        _ executable: String,
        _ arguments: [String],
        capture: Bool = false,
    ) -> Result<Void, ToolingError> {
        Result(catching: {
            let result = try run(executable, arguments, capture: capture).get()

            guard result.status == 0 else {
                throw ToolingError.command(executable, result.status, result.output)
            }
        }).mapError(ToolingError.from)
    }

    /// Returns captured command output only after validating a successful exit status.
    package func output(_ executable: String, _ arguments: [String]) -> Result<String, ToolingError> {
        Result(catching: {
            let result = try run(executable, arguments, capture: true).get()

            guard result.status == 0 else {
                throw ToolingError.command(executable, result.status, result.output)
            }

            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }).mapError(ToolingError.from)
    }

    /// Refuses a different Xcode build, including the command-line-tools-only installation.
    package func requireXcode() -> Result<Void, ToolingError> {
        Result(catching: {
            let actual = try output("/usr/bin/xcodebuild", ["-version"]).get()
            let expected = "Xcode \(pins.xcodeVersion)\nBuild version \(pins.xcodeBuild)"

            guard actual == expected else {
                throw ToolingError.invalid(
                    "Expected \(expected); selected installation reports \(actual). Set DEVELOPER_DIR to the pinned Xcode installation.",
                )
            }
        }).mapError(ToolingError.from)
    }

    /// Checks the repository-local linter rather than accepting a global executable.
    package func requireSwiftLint() -> Result<Void, ToolingError> {
        Result(catching: {
            try requireTool(swiftLintRelease).get()
        }).mapError(ToolingError.from)
    }

    /// Checks the sole formatter against its own release pin.
    package func requireSwiftFormat() -> Result<Void, ToolingError> {
        Result(catching: {
            try requireTool(swiftFormatRelease).get()
        }).mapError(ToolingError.from)
    }

    /// Installs both checksum-verified tools locally, reusing matching installations.
    package func bootstrap() -> Result<Void, ToolingError> {
        Result(catching: {
            try requireXcode().get()

            for tool in [swiftLintRelease, swiftFormatRelease] {
                try install(tool).get()
            }
        }).mapError(ToolingError.from)
    }

    /// Verifies downloaded bytes against the selected tool's pin before extraction or execution.
    package func verifyArchive(_ archive: URL, expectedSHA256: String) -> Result<Void, ToolingError> {
        Result(catching: {
            let digest = try SHA256.hash(data: Data(contentsOf: archive))
                .map { byte in
                    let digits = String(byte, radix: 16)

                    return digits.count == 1 ? "0" + digits : digits
                }
                .joined()

            guard digest == expectedSHA256 else {
                throw ToolingError.invalid("Tool archive checksum mismatch. Nothing was installed.")
            }
        }).mapError(ToolingError.from)
    }

    /// Reports toolchain identity after validating the compiler, formatter, and linter pins.
    package func doctor() -> Result<Void, ToolingError> {
        Result(catching: {
            try requireXcode().get()
            try requireSwiftLint().get()
            try requireSwiftFormat().get()
            print("Xcode \(pins.xcodeVersion) (\(pins.xcodeBuild)), SwiftLint \(pins.swiftLintVersion), and SwiftFormat \(pins.swiftFormatVersion) match the pins.")
            try checked("/usr/bin/xcrun", ["swift", "--version"]).get()
        }).mapError(ToolingError.from)
    }

    /// Collects sorted, unique Swift files, including untracked files, without following symlinks.
    package func sources(_ paths: [String]) -> Result<[String], ToolingError> {
        Result(catching: {
            var files = Set<String>()
            let inputs = paths.isEmpty ? [root.path] : paths
            for path in inputs {
                let url = URL(fileURLWithPath: path, relativeTo: callerDirectory).standardizedFileURL
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ToolingError.invalid("Source path does not exist: \(path)")
                }

                try files.formUnion(swiftFiles(at: url).get())
            }
            guard !files.isEmpty else {
                throw ToolingError.invalid(
                    "No Swift source files found. Provide a source path or add your Xcode project.",
                )
            }

            return files.sorted()
        }).mapError(ToolingError.from)
    }

    /// Checks or applies SwiftFormat, then the layout rules SwiftFormat has no rule for.
    ///
    /// Fixing runs SwiftFormat, inserts the line breaks the layout rules require, and runs
    /// SwiftFormat again to settle indentation. Blank lines between steps stay the author's.
    package func format(_ paths: [String], fix: Bool = false) -> Result<Void, ToolingError> {
        Result(catching: {
            try requireXcode().get()
            try requireSwiftFormat().get()

            var arguments = ["--config", root.appendingPathComponent(".swiftformat").path, "--cache", "ignore"]
            if !fix {
                arguments.append("--lint")
            }

            let files = try sources(paths).get()
            try checked(swiftFormat.path, arguments + files).get()
            if fix {
                try applyLayout(to: files).get()
                try checked(swiftFormat.path, arguments + files).get()
            }

            try checkLayout(of: files).get()
        }).mapError(ToolingError.from)
    }

    /// Applies the curated lint policy with no cached findings or global linter dependency.
    package func lint(_ paths: [String]) -> Result<Void, ToolingError> {
        Result(catching: {
            try requireXcode().get()
            try requireSwiftLint().get()

            let files = try sources(paths).get()
            for file in files {
                let source = try String(contentsOfFile: file, encoding: .utf8)
                let findings = try SoftDeprecations.diagnostics(source, file: file).get()
                guard findings.isEmpty else {
                    throw ToolingError.invalid(findings.joined(separator: "\n"))
                }
            }
            let tests = files.filter(isTestSource)
            let production = files.filter {
                !isTestSource($0)
            }

            for (selection, testProfile) in [(production, false), (tests, true)] where !selection.isEmpty {
                var arguments = ["lint", "--strict", "--no-cache", "--config", root.appendingPathComponent(".swiftlint.yml").path]

                if testProfile {
                    arguments += ["--config", root.appendingPathComponent(".swiftlint-tests.yml").path]
                }

                try checked(swiftLint.path, arguments + selection).get()
            }
        }).mapError(ToolingError.from)
    }

    /// Runs the non-mutating static gate, independent of application build and test commands.
    package func check(_ paths: [String]) -> Result<Void, ToolingError> {
        Result(catching: {
            try format(paths).get()
            try lint(paths).get()
        }).mapError(ToolingError.from)
    }

    /// Formats source and checks remaining findings without applying semantic lint fixes.
    package func fix(_ paths: [String]) -> Result<Void, ToolingError> {
        Result(catching: {
            try requireSwiftLint().get()
            try format(paths, fix: true).get()
            try check(paths).get()
        }).mapError(ToolingError.from)
    }

    /// Runs the tooling package's Swift Testing suite with compiler warnings treated as errors.
    package func test() -> Result<Void, ToolingError> {
        Result(catching: {
            try requireXcode().get()
            try requireSwiftLint().get()
            try requireSwiftFormat().get()
            try checked(
                "/usr/bin/xcrun",
                [
                    "swift",
                    "test",
                    "--package-path",
                    root.appendingPathComponent("scripts").path,
                    "-Xswiftc",
                    "-warnings-as-errors",
                ],
            ).get()
        }).mapError(ToolingError.from)
    }

    /// Removes an owned scratch directory; cleanup failures remain visible without hiding the original error.
    package func cleanup(_ url: URL) {
        let removal = Result(catching: {
            try FileManager.default.removeItem(at: url)
        })
        if case let .failure(error) = removal {
            FileHandle.standardError.write(Data("warning: Could not remove \(url.path): \(error)\n".utf8))
        }
    }

    /// Rewrites each file with the fixable layout rules, leaving unchanged files untouched.
    private func applyLayout(to files: [String]) -> Result<Void, ToolingError> {
        Result(catching: {
            for file in files {
                let source = try String(contentsOfFile: file, encoding: .utf8)
                let laidOut = try Layout.fixed(source).get()
                if laidOut != source {
                    try laidOut.write(toFile: file, atomically: true, encoding: .utf8)
                }
            }
        }).mapError(ToolingError.from)
    }

    /// Fails with every layout finding across the files, in editor-compatible form.
    private func checkLayout(of files: [String]) -> Result<Void, ToolingError> {
        Result(catching: {
            var findings: [String] = []
            for file in files {
                let source = try String(contentsOfFile: file, encoding: .utf8)
                findings += try Layout.diagnostics(source, file: file).get()
            }
            guard findings.isEmpty else {
                throw ToolingError.invalid(findings.joined(separator: "\n"))
            }
        }).mapError(ToolingError.from)
    }

    /// Finds the Swift files at a path: the file itself, or every Swift file below a directory.
    ///
    /// Symbolic links and the excluded directories yield no files.
    private func swiftFiles(at url: URL) -> Result<[String], ToolingError> {
        Result(catching: {
            let values = try url.resourceValues(forKeys: [
                .isSymbolicLinkKey,
                .isDirectoryKey,
                .isRegularFileKey,
            ])
            guard values.isSymbolicLink != true else {
                return []
            }

            if values.isDirectory == true {
                guard !Self.excludedDirectories.contains(url.lastPathComponent) else {
                    return []
                }

                let children = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                )

                return try children.flatMap {
                    try swiftFiles(at: $0).get()
                }
            }
            guard values.isRegularFile == true, url.pathExtension == "swift" else {
                return []
            }

            return [url.standardizedFileURL.path]
        }).mapError(ToolingError.from)
    }

    /// Identifies conventional test paths for the documentation-only profile.
    private func isTestSource(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)

        return url
            .deletingLastPathComponent()
            .pathComponents
            .contains {
                $0.hasSuffix("Tests")
            }
            || url.lastPathComponent.hasSuffix("Tests.swift")
    }

    /// Locates a release executable inside the checkout-owned installation directory.
    private func binary(for tool: ToolRelease) -> URL {
        root.appendingPathComponent(".tools/\(tool.name)/\(tool.version)/\(tool.name)")
    }

    /// Requires a runnable executable whose reported release matches the pin.
    private func requireTool(_ tool: ToolRelease) -> Result<Void, ToolingError> {
        Result(catching: {
            let executable = binary(for: tool)

            guard FileManager.default.isExecutableFile(atPath: executable.path) else {
                throw ToolingError.invalid("Repository-local \(tool.name) is missing. Run ./scripts/dev.swift bootstrap.")
            }

            let actual = try output(executable.path, tool.versionArguments).get()

            guard actual == tool.version else {
                throw ToolingError.invalid("Expected \(tool.name) \(tool.version); found \(actual). Inspect the local installation.")
            }
        }).mapError(ToolingError.from)
    }

    /// Publishes an installation only after archive and executable verification.
    private func install(_ tool: ToolRelease) -> Result<Void, ToolingError> {
        Result(catching: {
            let manager = FileManager.default

            if manager.fileExists(atPath: binary(for: tool).path) {
                try requireTool(tool).get()
                print("\(tool.name) \(tool.version) is already installed.")

                return
            }

            let installRoot = root.appendingPathComponent(".tools/\(tool.name)")

            try manager.createDirectory(at: installRoot, withIntermediateDirectories: true)

            let staging = installRoot.appendingPathComponent(".install-\(UUID().uuidString)")

            try manager.createDirectory(at: staging, withIntermediateDirectories: false)

            defer {
                cleanup(staging)
            }

            let archive = staging.appendingPathComponent("release.zip")

            try checked(
                "/usr/bin/curl",
                ["--fail", "--location", "--proto", "=https", "--tlsv1.2", "--retry", "2", tool.downloadURL, "--output", archive.path],
            ).get()
            try verifyArchive(archive, expectedSHA256: tool.sha256).get()

            let unpacked = staging.appendingPathComponent("unpacked")

            try checked("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path]).get()

            let executable = unpacked.appendingPathComponent(tool.name)

            guard manager.fileExists(atPath: executable.path) else {
                throw ToolingError.invalid("The verified \(tool.name) archive has an unexpected layout.")
            }

            try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

            let version = try output(executable.path, tool.versionArguments).get()

            guard version == tool.version else {
                throw ToolingError.invalid("The verified \(tool.name) binary reports an unexpected version.")
            }

            let destination = installRoot.appendingPathComponent(tool.version)

            guard !manager.fileExists(atPath: destination.path) else {
                throw ToolingError.invalid("An installation already exists at \(destination.path). Inspect it before replacing it.")
            }

            try manager.moveItem(at: unpacked, to: destination)
            try requireTool(tool).get()
            print("Installed \(tool.name) \(tool.version) locally. No global tools were changed.")
        }).mapError(ToolingError.from)
    }
}
