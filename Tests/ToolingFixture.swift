/// A minimal namespace used to verify the template's tooling, not an application architecture.
public enum ToolingFixture {
    /// Returns the supplied value unchanged.
    public static func identity(_ value: Int) -> Int {
        value
    }
}
