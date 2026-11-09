import Testing
@testable import ToolingCore

struct SoftDeprecationsTests {
    @Test(arguments: [
        "NavigationView { Text(\"Hello\") }",
        "SwiftUI.NavigationView { Text(\"Hello\") }",
        "view.foregroundColor(.red)",
        "view.cornerRadius(8)",
        "view.tabItem { Text(\"Home\") }",
        "view.toolbar(.hidden, for: .navigationBar)",
        "view.toolbarBackground(.visible, for: .navigationBar)",
        "NavigationLink(destinationName: \"details\") { Text(\"Go\") }",
        "let value: Alert? = nil",
        "let value: SwiftUI.NavigationView<Text>? = nil",
    ])
    func `legacy references produce located actionable findings`(expression: String) throws {
        let source = "import SwiftUI\n\(expression)\n"
        let findings = try SoftDeprecations.diagnostics(source, file: "View.swift").get()

        #expect(findings.count == 1)
        #expect(findings.allSatisfy {
            $0.hasPrefix("View.swift:2:") && $0.contains("Use ")
        })
    }

    @Test
    func `modern overloads environment keys comments and literals are not legacy calls`() throws {
        let source = #"""
        import SwiftUI
        // NavigationView and .foregroundColor are examples.
        let example = "NavigationView .cornerRadius"
        @Environment(\.colorScheme) var scheme
        NavigationStack { Text("Hello").foregroundStyle(.red) }
        view.background(.red)
        view.background { Color.red }
        view.overlay(alignment: .center) { Text("Hello") }
        view.toolbar { ToolbarItem { Text("Hello") } }
        view.toolbarVisibility(.hidden, for: .navigationBar)
        NavigationLink(value: "details") { Text("Go") }
        struct Alert {}
        """#

        #expect(try SoftDeprecations.diagnostics(source, file: "View.swift").get().isEmpty)
        #expect(try SoftDeprecations.diagnostics("let item = NavigationView()", file: "Model.swift").get().isEmpty)
    }

    @Test
    func `conditional SwiftUI imports still participate in the scan`() throws {
        let source = "#if canImport(SwiftUI)\nimport SwiftUI\nlet view = NavigationView { Text(\"Hello\") }\n#endif"

        #expect(try SoftDeprecations.diagnostics(source, file: "View.swift").get().count == 1)
    }

    @Test
    func `string interpolation is executable and malformed source fails closed`() throws {
        let source = #"import SwiftUI; let text = "\(NavigationView { Text("Hi") })""#

        #expect(try SoftDeprecations.diagnostics(source, file: "View.swift").get().count == 1)

        guard case .failure = SoftDeprecations.diagnostics("import SwiftUI; func broken(", file: "View.swift") else {
            Issue.record("Malformed Swift source must fail the API-currency scan.")

            return
        }
    }
}
