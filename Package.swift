// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "kakao-summarizer",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "KakaoReadCore"),
        .executableTarget(name: "kakao-read", dependencies: ["KakaoReadCore"]),
        .testTarget(name: "KakaoReadCoreTests", dependencies: ["KakaoReadCore"]),
    ],
    swiftLanguageModes: [.v5]
)
