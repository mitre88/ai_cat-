// swift-tools-version: 5.9
// AICatCore: platform-neutral game logic (Foundation only) so it can be tested with `swift test`
// without a simulator, and cross-checked against the Python reference model in Tools/.
import PackageDescription

let package = Package(
    name: "AICatCore",
    products: [
        .library(name: "AICatCore", targets: ["AICatCore"]),
    ],
    targets: [
        .target(name: "AICatCore"),
        .testTarget(name: "AICatCoreTests", dependencies: ["AICatCore"]),
    ]
)
