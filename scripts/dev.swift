#!/usr/bin/env swift
import Foundation

/// The checkout containing this launcher and its tooling package.
let root = URL(fileURLWithPath: #filePath)
    .standardizedFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()

/// The SwiftPM invocation whose status becomes this command's exit status.
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
process.arguments =
    [
        "swift",
        "run",
        "--quiet",
        "--package-path",
        root.appendingPathComponent("scripts").path,
        "-Xswiftc",
        "-warnings-as-errors",
        "template",
    ] + Array(CommandLine.arguments.dropFirst())

/// The child-only environment selecting this checkout and Xcode toolchain.
var environment = ProcessInfo.processInfo.environment
environment["SWIFTUI_TEMPLATE_ROOT"] = root.path
environment["TOOLCHAINS"] = "com.apple.dt.toolchain.XcodeDefault"
process.environment = environment

switch Result(catching: {
    try process.run()
}) {
case .success:
    process.waitUntilExit()
    exit(process.terminationStatus)

case let .failure(error):
    FileHandle.standardError.write(Data("error: Could not launch Swift tooling: \(error)\n".utf8))
    exit(1)
}
