import SwiftSyntax

/// Splits chained calls one per line, with the chain's start alone on the first line.
///
/// A chain splits when two or more calls follow its start. In SwiftUI view code, a view and
/// any modifier also split. SwiftFormat's `wrapMultilineFunctionChains` then puts every later
/// call on its own line, so this rule only has to break the line before the first call.
final class ChainLines: LayoutVisitor {
    /// Creates the visitor for the chain-lines rule.
    init() {
        super.init(rule: .chainLines)
    }

    /// Judges a chain that ends in a call.
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        judge(ExprSyntax(node))

        return .visitChildren
    }

    /// Judges a chain that ends in a property.
    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        judge(ExprSyntax(node))

        return .visitChildren
    }

    /// Whether an expression is the outermost of its chain, so each chain is judged once.
    private static func isOutermost(_ expression: ExprSyntax) -> Bool {
        var node = Syntax(expression)
        while let parent = node.parent, parent.is(OptionalChainingExprSyntax.self) {
            node = parent
        }
        guard let parent = node.parent else {
            return true
        }
        if let member = parent.as(MemberAccessExprSyntax.self), member.base?.id == node.id {
            return false
        }

        return parent.as(FunctionCallExprSyntax.self)?.calledExpression.id != node.id
    }

    /// Whether an expression sits in string interpolation, where a line break would end the literal.
    private static func isInsideString(_ expression: ExprSyntax) -> Bool {
        sequence(first: Syntax(expression), next: \.parent).contains {
            $0.is(StringLiteralExprSyntax.self)
        }
    }

    /// Whether an expression sits in code that builds SwiftUI views.
    ///
    /// The nearest typed declaration decides: a `some View` type or result, `@ViewBuilder`, or
    /// `#Preview`. Locals without a type annotation are skipped, so a view bound to a local still counts.
    private static func isViewCode(_ expression: ExprSyntax) -> Bool {
        for ancestor in sequence(first: Syntax(expression), next: \.parent) {
            if let macro = ancestor.as(MacroExpansionDeclSyntax.self), macro.macroName.text == "Preview" {
                return true
            }
            if let function = ancestor.as(FunctionDeclSyntax.self) {
                return isViewBuilder(function.attributes) || isView(function.signature.returnClause?.type)
            }
            if let variable = ancestor.as(VariableDeclSyntax.self), isTyped(variable) {
                return isViewBuilder(variable.attributes) || variable.bindings.contains {
                    isView($0.typeAnnotation?.type)
                }
            }
        }

        return false
    }

    /// Whether any binding in a variable declaration has a written type.
    private static func isTyped(_ variable: VariableDeclSyntax) -> Bool {
        variable.bindings.contains {
            $0.typeAnnotation != nil
        }
    }

    /// Whether a type is `some View`.
    private static func isView(_ type: TypeSyntax?) -> Bool {
        guard let opaque = type?.as(SomeOrAnyTypeSyntax.self) else {
            return false
        }

        return opaque.someOrAnySpecifier.tokenKind == .keyword(.some) && opaque.constraint.trimmedDescription == "View"
    }

    /// Whether a declaration is marked `@ViewBuilder`.
    private static func isViewBuilder(_ attributes: AttributeListSyntax) -> Bool {
        attributes.contains {
            $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ViewBuilder"
        }
    }

    /// Requires the first call after a chain's start to begin a line when the chain splits.
    private func judge(_ expression: ExprSyntax) {
        guard Self.isOutermost(expression), !Self.isInsideString(expression) else {
            return
        }

        let chain = CallChain(expression)
        let viewWithModifier = chain.callCount == 1 && chain.startsWithTypeInitializer && Self.isViewCode(expression)
        if chain.callCount >= 2 || viewWithModifier, let split = chain.splitPoint {
            requireLineStart(split.period)
        }
    }
}

/// A chain of member accesses, read from its outermost expression down to its start.
struct CallChain {
    /// One member access in the chain, and whether it is called.
    private struct Link {
        /// The member access, whose period is where a split line begins.
        let member: MemberAccessExprSyntax
        /// Whether the member is a call rather than a property.
        let isCall: Bool
        /// Whether the member is an argument-free `get()`, as `Result` unwraps with.
        let isUnwrap: Bool
    }

    /// The expression the chain starts from, before its first member access.
    private let start: ExprSyntax
    /// The member accesses after the start, in source order.
    private let links: [Link]

    /// How many calls follow the chain's start.
    var callCount: Int {
        linksAfterStart.count {
            $0.isCall
        }
    }

    /// The first call after the start: the line break goes before its period.
    var splitPoint: MemberAccessExprSyntax? {
        linksAfterStart.first?.member
    }

    /// Whether the chain starts by constructing a type, as `Text("Title")` or `VStack { … }` do.
    var startsWithTypeInitializer: Bool {
        guard let call = start.as(FunctionCallExprSyntax.self) else {
            return false
        }

        return Self.isTypeReference(call.calledExpression)
    }

    /// The links after the start, which takes in leading properties and a type's static call.
    ///
    /// A final argument-free `get()` does not count, so `try tooling.fix(paths).get()` keeps its line.
    /// `Percentage.make(n).mapError { … }` and `FileManager.default.removeItem(at:)` each have one
    /// call after their start, while `notes.filter { … }.map { … }` has two.
    private var linksAfterStart: ArraySlice<Link> {
        var index = links.startIndex
        if Self.isTypeReference(start), links.first?.isCall == true {
            index += 1
        }
        while index < links.endIndex, !links[index].isCall {
            index += 1
        }

        let end = links.last?.isUnwrap == true ? links.endIndex - 1 : links.endIndex

        return links[index ..< max(index, end)]
    }

    /// Reads the chain that ends at an expression.
    init(_ expression: ExprSyntax) {
        var links: [Link] = []
        var current = expression
        while let step = Self.peel(current) {
            links.append(step.link)
            current = step.base
        }
        start = current
        self.links = links.reversed()
    }

    /// Steps from an expression to the base of its last member access, skipping optional chaining.
    private static func peel(_ expression: ExprSyntax) -> (link: Link, base: ExprSyntax)? {
        if let optional = expression.as(OptionalChainingExprSyntax.self) {
            return peel(optional.expression)
        }
        if let call = expression.as(FunctionCallExprSyntax.self),
           let member = call.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base
        {
            let isUnwrap = member.declName.baseName.text == "get" && call.arguments.isEmpty && call.trailingClosure == nil

            return (Link(member: member, isCall: true, isUnwrap: isUnwrap), base)
        }
        guard let member = expression.as(MemberAccessExprSyntax.self), let base = member.base else {
            return nil
        }

        return (Link(member: member, isCall: false, isUnwrap: false), base)
    }

    /// Whether an expression names a type, judged by Swift's capitalized type names.
    private static func isTypeReference(_ expression: ExprSyntax) -> Bool {
        expression.as(DeclReferenceExprSyntax.self)?.baseName.text.first?.isUppercase == true
    }
}
