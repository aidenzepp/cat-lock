import SwiftSyntax

/// Finds closures inside guard, if and while conditions.
///
/// Only the author can fix these: binding the closure's result first moves the call above
/// earlier conditions, which changes what runs when one of them fails.
final class ConditionClosures: SyntaxVisitor {
    /// Where each offending closure opens.
    private(set) var positions: [AbsolutePosition] = []

    /// Creates a visitor that reads source exactly as written.
    init() {
        super.init(viewMode: .sourceAccurate)
    }

    /// Checks guard conditions.
    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        inspect(node.conditions)

        return .visitChildren
    }

    /// Checks if conditions, including those of else-if branches.
    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        inspect(node.conditions)

        return .visitChildren
    }

    /// Checks while conditions.
    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        inspect(node.conditions)

        return .visitChildren
    }

    /// Records the first brace of each condition; in a condition, only a closure opens a brace.
    private func inspect(_ conditions: ConditionElementListSyntax) {
        for condition in conditions {
            let brace = condition
                .tokens(viewMode: .sourceAccurate)
                .first {
                    $0.tokenKind == .leftBrace
                }
            if let brace {
                positions.append(brace.positionAfterSkippingLeadingTrivia)
            }
        }
    }
}
