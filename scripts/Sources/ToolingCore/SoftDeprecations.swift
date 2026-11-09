import SwiftParser
import SwiftSyntax

/// Checks a curated, syntax-identifiable subset of Apple's Xcode 27 SwiftUI soft-deprecation list.
package enum SoftDeprecations {
    /// Returns source-located diagnostics; overloads requiring type resolution remain a review responsibility.
    package static func diagnostics(_ source: String, file: String) -> Result<[String], ToolingError> {
        let tree = Parser.parse(source: source)

        guard !tree.hasError else {
            return .failure(.invalid("\(file): cannot scan soft deprecations in malformed Swift source."))
        }

        let visitor = SoftDeprecationVisitor(file: file, tree: tree)

        visitor.walk(tree)

        return .success(visitor.importsSwiftUI ? visitor.findings
            .sorted {
                $0.key < $1.key
            }
            .map(\.value) : [])
    }
}

/// Finds references and calls while excluding comments, string contents, and declarations with similar names.
private final class SoftDeprecationVisitor: SyntaxVisitor {
    /// Legacy type names whose replacements are recorded in Apple's bundled API list.
    private static let types: [String: String] = [
        "ActionSheet": "confirmationDialog",
        "Alert": "the alert modifier",
        "CarouselTabViewStyle": "VerticalTabViewStyle",
        "ColumnNavigationViewStyle": "NavigationSplitView",
        "ContentSizeCategory": "DynamicTypeSize",
        "ContextMenu": "contextMenu(menuItems:)",
        "ControlActiveState": "EnvironmentValues.appearsActive",
        "DefaultNavigationViewStyle": "NavigationStack or NavigationSplitView",
        "DoubleColumnNavigationViewStyle": "NavigationStack or NavigationSplitView",
        "MagnificationGesture": "MagnifyGesture",
        "MenuButton": "Menu",
        "NavigationView": "NavigationStack or NavigationSplitView",
        "NavigationViewStyle": "NavigationStack or NavigationSplitView",
        "PresentationMode": "EnvironmentValues.dismiss or isPresented",
        "RotationGesture": "RotateGesture",
        "StackNavigationViewStyle": "NavigationStack",
        "AnimatableModifier": "Animatable directly",
    ]

    /// Call names whose SwiftUI overloads in the bundled inventory have modern replacements.
    private static let modifiers: [String: String] = [
        "accentColor": "tint or the asset catalog accent color",
        "autocapitalization": "textInputAutocapitalization on iOS",
        "colorScheme": "preferredColorScheme",
        "cornerRadius": "clipShape(.rect(cornerRadius:)) or fill",
        "disableAutocorrection": "autocorrectionDisabled",
        "edgesIgnoringSafeArea": "ignoresSafeArea",
        "foregroundColor": "foregroundStyle",
        "navigationBarHidden": "toolbarVisibility",
        "navigationBarItems": "toolbar content",
        "navigationBarTitle": "navigationTitle and navigationBarTitleDisplayMode",
        "tabItem": "Tab",
    ]

    /// Includes selective and conditional imports, not only direct source-file statements.
    var importsSwiftUI = false

    /// Diagnostics keyed by source offset to avoid duplicate type and expression visits.
    var findings: [Int: String] = [:]

    /// Source path used in editor-compatible diagnostics.
    private let file: String
    /// Resolves UTF-8 syntax positions to source lines and columns.
    private let locations: SourceLocationConverter

    /// Shares the parser's original source positions with every diagnostic.
    init(file: String, tree: SourceFileSyntax) {
        self.file = file
        locations = SourceLocationConverter(fileName: file, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    /// Detects SwiftUI modules even when the import is under conditional compilation.
    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if ["SwiftUI", "SwiftUICore"].contains(node.path.first?.name.text ?? "") {
            importsSwiftUI = true
        }

        return .visitChildren
    }

    /// Checks constructor references without matching declaration names or literal text.
    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        recordType(node.baseName)

        return .visitChildren
    }

    /// Checks type annotations as well as constructor expressions.
    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        recordType(node.name)

        return .visitChildren
    }

    /// Checks qualified type annotations such as SwiftUI.NavigationView.
    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        recordType(node.name)

        return .visitChildren
    }

    /// Checks modifier calls and overloads whose obsolete argument labels are unambiguous.
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self),
           let replacement = Self.modifiers[member.declName.baseName.text]
        {
            record(member.declName.baseName, replacement: replacement)
        }

        let usesDestinationName = node.arguments.contains {
            $0.label?.text == "destinationName"
        }
        if let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName,
           name.text == "NavigationLink", usesDestinationName
        {
            record(name, replacement: "NavigationLink(value:label:)")
        }

        // Visibility variables and view-vs-ShapeStyle overloads require semantic analysis; never guess here.
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self),
           ["toolbar", "toolbarBackground"].contains(member.declName.baseName.text),
           let first = node.arguments.first, first.label == nil,
           let visibility = first.expression.as(MemberAccessExprSyntax.self), visibility.base == nil,
           ["hidden", "visible", "automatic"].contains(visibility.declName.baseName.text)
        {
            record(member.declName.baseName, replacement: member.declName.baseName.text + "Visibility")
        }

        return .visitChildren
    }

    /// Associates a legacy type with its documented replacement when it is in the curated inventory.
    private func recordType(_ name: TokenSyntax) {
        if let replacement = Self.types[name.text] {
            record(name, replacement: replacement)
        }
    }

    /// Emits one actionable finding at the identifier's original location.
    private func record(_ name: TokenSyntax, replacement: String) {
        let position = name.positionAfterSkippingLeadingTrivia
        let location = locations.location(for: position)

        findings[position.utf8Offset] = "\(file):\(location.line):\(location.column): error: \(name.text) is soft-deprecated in SwiftUI. Use \(replacement). (soft_deprecated_swiftui)"
    }
}
