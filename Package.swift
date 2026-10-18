// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeSwitchVoice",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CodeSwitchVoice",
            targets: ["CodeSwitchVoice"]
        ),
        .executable(
            name: "codeswitch",
            targets: ["CodeSwitchVoiceCLI"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CodeSwitchVoice",
            dependencies: [],
            path: "Sources/CodeSwitchVoice"
        ),
        .executableTarget(
            name: "CodeSwitchVoiceCLI",
            dependencies: ["CodeSwitchVoice"],
            path: "Sources/CodeSwitchVoiceCLI"
        ),
        .testTarget(
            name: "CodeSwitchVoiceTests",
            dependencies: ["CodeSwitchVoice"],
            path: "Tests/CodeSwitchVoiceTests"
        )
    ]
)
