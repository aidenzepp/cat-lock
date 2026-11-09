import ArgumentParser
import Foundation
import ToolingCore

/// Shared repository selection for every subcommand.
struct RepositoryOptions: ParsableArguments {
    /// The checkout whose policy and local tools the command uses.
    @Option(help: "Template repository root; the launcher supplies it automatically.")
    var root: String =
        ProcessInfo.processInfo.environment["SWIFTUI_TEMPLATE_ROOT"]
            ?? FileManager.default.currentDirectoryPath

    /// Loads the selected checkout and validates its tool-pin configuration.
    func execute(_ action: (Tooling) -> Result<Void, ToolingError>) {
        if case let .failure(error) = Tooling.load(root: URL(fileURLWithPath: root)).flatMap(action) {
            TemplateCommand.exit(withError: error)
        }
    }
}

/// Explicit source paths, or automatic repository-wide Swift discovery when omitted.
struct SourceOptions: ParsableArguments {
    /// Explicit source paths, or repository-wide discovery when omitted.
    @Argument(help: "Swift files or directories to check; defaults to this repository.")
    var paths: [String] = []
}

/// Repository commands backed by Apple's type-safe ArgumentParser package.
@main
struct TemplateCommand: ParsableCommand {
    /// Defines generated help and dispatch metadata for this command.
    static let configuration = CommandConfiguration(
        commandName: "template",
        abstract: "Set up and verify the SwiftUI tooling baseline.",
        subcommands: [
            Bootstrap.self,
            Doctor.self,
            Format.self,
            Lint.self,
            Check.self,
            Fix.self,
            Test.self,
        ],
    )
}

/// Installs the verified repository-local formatter and linter.
struct Bootstrap: ParsableCommand {
    /// Defines generated help and dispatch metadata for this command.
    static let configuration = CommandConfiguration(
        abstract: "Install the pinned, checksum-verified formatter and linter.",
    )

    /// The shared checkout selection used by this command.
    @OptionGroup var repository: RepositoryOptions

    /// Installs the verified repository-local formatter and linter.
    mutating func run() {
        repository.execute {
            $0.bootstrap()
        }
    }
}

/// Verifies the compiler, formatter, and linter release pins.
struct Doctor: ParsableCommand {
    /// Defines generated help and dispatch metadata for this command.
    static let configuration = CommandConfiguration(
        abstract: "Verify selected Xcode and repository-local tools.",
    )

    /// The shared checkout selection used by this command.
    @OptionGroup var repository: RepositoryOptions

    /// Verifies the compiler, formatter, and linter release pins.
    mutating func run() {
        repository.execute {
            $0.doctor()
        }
    }
}

/// Checks source layout without changing files.
struct Format: ParsableCommand {
    /// Defines generated help and dispatch metadata for this command.
    static let configuration = CommandConfiguration(
        abstract: "Check SwiftFormat formatting without edits.",
    )

    /// The shared checkout selection used by this command.
    @OptionGroup var repository: RepositoryOptions
    /// The source selection shared by formatting and lint commands.
    @OptionGroup var sources: SourceOptions

    /// Checks source layout without changing files.
    mutating func run() {
        repository.execute {
            $0.format(sources.paths)
        }
    }
}

/// Checks documentation, safety, and performance policy.
struct Lint: ParsableCommand {
    /// Defines generated help and dispatch metadata for this command.
    static let configuration = CommandConfiguration(
        abstract: "Enforce the strict safety and documentation rules.",
    )

    /// The shared checkout selection used by this command.
    @OptionGroup var repository: RepositoryOptions
    /// The source selection shared by formatting and lint commands.
    @OptionGroup var sources: SourceOptions

    /// Checks documentation, safety, and performance policy.
    mutating func run() {
        repository.execute {
            $0.lint(sources.paths)
        }
    }
}

/// Runs both non-mutating static verification stages.
struct Check: ParsableCommand {
    /// Defines generated help and dispatch metadata for this command.
    static let configuration = CommandConfiguration(
        abstract: "Run non-mutating format and lint checks.",
    )

    /// The shared checkout selection used by this command.
    @OptionGroup var repository: RepositoryOptions
    /// The source selection shared by formatting and lint commands.
    @OptionGroup var sources: SourceOptions

    /// Runs both non-mutating static verification stages.
    mutating func run() {
        repository.execute {
            $0.check(sources.paths)
        }
    }
}

/// Applies formatting and checks remaining policy violations.
struct Fix: ParsableCommand {
    /// Defines generated help and dispatch metadata for this command.
    static let configuration = CommandConfiguration(
        abstract: "Apply the formatter, then check remaining lint findings.",
    )

    /// The shared checkout selection used by this command.
    @OptionGroup var repository: RepositoryOptions
    /// The source selection shared by formatting and lint commands.
    @OptionGroup var sources: SourceOptions

    /// Applies formatting and checks remaining policy violations.
    mutating func run() {
        repository.execute {
            $0.fix(sources.paths)
        }
    }
}

/// Executes the tooling package regression tests.
struct Test: ParsableCommand {
    /// Defines generated help and dispatch metadata for this command.
    static let configuration = CommandConfiguration(
        abstract: "Run the tooling package's Swift Testing suite.",
    )

    /// The shared checkout selection used by this command.
    @OptionGroup var repository: RepositoryOptions

    /// Executes the tooling package regression tests.
    mutating func run() {
        repository.execute {
            $0.test()
        }
    }
}
