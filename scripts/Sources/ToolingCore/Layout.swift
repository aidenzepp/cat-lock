import SwiftParser
import SwiftSyntax

/// Applies the layout rules SwiftFormat has no rule for, as line breaks that never change a token.
package enum Layout {
    /// The most rounds one fix runs; a round can reveal a break that an earlier break made necessary.
    private static let maximumRounds = 4

    /// Returns the source with every fixable layout rule applied.
    ///
    /// Only line breaks are added, so the next SwiftFormat run settles indentation and spacing.
    package static func fixed(_ source: String) -> Result<String, ToolingError> {
        Result(catching: {
            var current = source
            for _ in 0 ..< maximumRounds {
                let breaks = try scan(current).get().breaks
                guard !breaks.isEmpty else {
                    return current
                }

                current = inserting(breaks, into: current)
            }

            return current
        }).mapError(ToolingError.from)
    }

    /// Returns an editor-compatible diagnostic for every layout rule the source breaks.
    package static func diagnostics(_ source: String, file: String) -> Result<[String], ToolingError> {
        scan(source).map {
            $0.diagnostics(file: file)
        }
    }

    /// Parses source and runs every rule, refusing malformed syntax before proposing edits.
    private static func scan(_ source: String) -> Result<LayoutScan, ToolingError> {
        let tree = Parser.parse(source: source)
        guard !tree.hasError else {
            return .failure(.invalid("Cannot check layout in malformed Swift source."))
        }

        return .success(LayoutScan(tree: tree))
    }

    /// Inserts one line break at each required offset, matching the source's line endings.
    private static func inserting(_ breaks: [LineBreak], into source: String) -> String {
        var bytes = Array(source.utf8)
        let newline: [UInt8] = source.contains("\r\n") ? [13, 10] : [10]
        for offset in Set(breaks.map(\.offset)).sorted(by: >) {
            bytes.insert(contentsOf: newline, at: offset)
        }

        return String(decoding: bytes, as: UTF8.self)
    }
}

/// A layout rule, named in diagnostics so a finding traces back to its rule.
enum LayoutRule: String {
    /// A defer, accessor or deinit body shares a line with its braces.
    case bodyLines = "layout_body_lines"
    /// An exit that ends its block has no blank line above it.
    case exitBlankLine = "layout_exit_blank_line"
    /// A chain of calls is not split one call per line after its start.
    case chainLines = "layout_chain_lines"
    /// A closure sits inside a guard, if or while condition.
    case conditionClosure = "layout_condition_closure"

    /// What to do about a finding, for the person or agent reading the diagnostic.
    var message: String {
        switch self {
        case .bodyLines:
            "Put this body on its own lines. Run ./scripts/dev.swift fix."
        case .exitBlankLine:
            "Put a blank line above an exit that ends its block. Run ./scripts/dev.swift fix."
        case .chainLines:
            "Put each call in this chain on its own line, below its start. Run ./scripts/dev.swift fix."
        case .conditionClosure:
            "Move this closure out of the condition: bind its result with let first, or split the condition into guards."
        }
    }
}

/// One line break a fixable rule requires.
struct LineBreak {
    /// The UTF-8 offset where the break is inserted, before the token's leading trivia.
    let offset: Int
    /// Where a diagnostic points: the token that must start a line.
    let position: AbsolutePosition
    /// The rule that requires the break.
    let rule: LayoutRule
}

/// Every rule's result for one parsed source file.
struct LayoutScan {
    /// Line breaks the fixable rules require.
    let breaks: [LineBreak]
    /// Closures inside conditions, which only the author can move.
    let conditionClosures: [AbsolutePosition]

    /// The parsed file, kept to resolve positions into lines and columns.
    private let tree: SourceFileSyntax

    /// Runs every rule over a parsed file.
    init(tree: SourceFileSyntax) {
        self.tree = tree
        breaks = [BodyLines(), ExitBlankLines(), ChainLines()].flatMap { visitor in
            visitor.walk(tree)

            return visitor.breaks
        }
        let closures = ConditionClosures()
        closures.walk(tree)
        conditionClosures = closures.positions
    }

    /// Formats each finding as `file:line:column: error: message (rule)`, in source order.
    func diagnostics(file: String) -> [String] {
        let locations = SourceLocationConverter(fileName: file, tree: tree)
        let findings = breaks.map {
            ($0.position, $0.rule)
        } + conditionClosures.map {
            ($0, LayoutRule.conditionClosure)
        }

        return findings
            .sorted {
                $0.0 < $1.0
            }
            .map { position, rule in
                let location = locations.location(for: position)

                return "\(file):\(location.line):\(location.column): error: \(rule.message) (\(rule.rawValue))"
            }
    }
}

/// Collects the line breaks one fixable layout rule requires.
class LayoutVisitor: SyntaxVisitor {
    /// Line breaks this rule requires, in visit order.
    private(set) var breaks: [LineBreak] = []

    /// The rule each collected break enforces.
    private let rule: LayoutRule

    /// Creates a visitor that reads source exactly as written.
    init(rule: LayoutRule) {
        self.rule = rule
        super.init(viewMode: .sourceAccurate)
    }

    /// Counts the line breaks in a token's leading trivia; trailing trivia never holds one.
    ///
    /// Stopping at comments counts only the breaks above the first comment, so a blank line
    /// lands above a comment that explains the token rather than between the two.
    private static func lineBreaks(before token: TokenSyntax, stoppingAtComments: Bool = false) -> Int {
        var count = 0
        for piece in token.leadingTrivia.pieces {
            switch piece {
            case let .newlines(lines), let .carriageReturns(lines), let .carriageReturnLineFeeds(lines):
                count += lines
            case .spaces, .tabs:
                continue
            default:
                if stoppingAtComments {
                    return count
                }
            }
        }

        return count
    }

    /// Requires a token to start its own line.
    final func requireLineStart(_ token: TokenSyntax) {
        guard token.previousToken(viewMode: .sourceAccurate) != nil, Self.lineBreaks(before: token) == 0 else {
            return
        }

        record(token)
    }

    /// Requires a blank line, not only a line break, between a token and the code above it.
    final func requireBlankLine(before token: TokenSyntax) {
        guard token.previousToken(viewMode: .sourceAccurate) != nil,
              Self.lineBreaks(before: token, stoppingAtComments: true) == 1
        else {
            return
        }

        record(token)
    }

    /// Records a break before the token's leading trivia, reported at the token itself.
    private func record(_ token: TokenSyntax) {
        breaks.append(LineBreak(
            offset: token.position.utf8Offset,
            position: token.positionAfterSkippingLeadingTrivia,
            rule: rule,
        ))
    }
}
