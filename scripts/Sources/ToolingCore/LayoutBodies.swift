import SwiftSyntax

/// Puts defer, accessor and deinit bodies on their own lines, which SwiftFormat leaves as written.
final class BodyLines: LayoutVisitor {
    /// Creates the visitor for the body-lines rule.
    init() {
        super.init(rule: .bodyLines)
    }

    /// Checks a defer body.
    override func visit(_ node: DeferStmtSyntax) -> SyntaxVisitorContinueKind {
        requireOwnLines(node.body)

        return .visitChildren
    }

    /// Checks the body of a get, set, willSet, didSet or other explicit accessor.
    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        if let body = node.body {
            requireOwnLines(body)
        }

        return .visitChildren
    }

    /// Checks a deinit body.
    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if let body = node.body {
            requireOwnLines(body)
        }

        return .visitChildren
    }

    /// Requires a non-empty body's first statement and closing brace to start their own lines.
    private func requireOwnLines(_ body: CodeBlockSyntax) {
        guard let first = body.statements.first?.firstToken(viewMode: .sourceAccurate) else {
            return
        }

        requireLineStart(first)
        requireLineStart(body.rightBrace)
    }
}

/// Puts a blank line above a return, continue or break that ends a block after other statements.
final class ExitBlankLines: LayoutVisitor {
    /// Creates the visitor for the exit-blank-line rule.
    init() {
        super.init(rule: .exitBlankLine)
    }

    /// Checks the last statement of every statement list: code blocks, closures, accessors and switch cases.
    override func visit(_ node: CodeBlockItemListSyntax) -> SyntaxVisitorContinueKind {
        if node.count > 1, let last = node.last, Self.isExit(last),
           let token = last.firstToken(viewMode: .sourceAccurate)
        {
            requireBlankLine(before: token)
        }

        return .visitChildren
    }

    /// Whether a statement leaves its block.
    private static func isExit(_ statement: CodeBlockItemSyntax) -> Bool {
        statement.item.is(ReturnStmtSyntax.self)
            || statement.item.is(ContinueStmtSyntax.self)
            || statement.item.is(BreakStmtSyntax.self)
    }
}
