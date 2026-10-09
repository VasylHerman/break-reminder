// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BreakReminder",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BreakReminder",
            path: "Sources/BreakReminder"
        ),
        .testTarget(
            name: "BreakReminderTests",
            dependencies: ["BreakReminder"],
            path: "Tests/BreakReminderTests"
        ),
    ]
)
