// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RightMouseMenu",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "RightMouseMenu", targets: ["RightMouseMenu"])],
    targets: [.executableTarget(name: "RightMouseMenu", path: "Sources", exclude: ["FinderExtension", "RightMouseMenu/Assets.xcassets"])]
)
