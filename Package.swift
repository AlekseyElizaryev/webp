// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "WebPViewer",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "WebPViewer", targets: ["WebPViewer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.3.2"),
    ],
    targets: [
        .executableTarget(
            name: "WebPViewer",
            dependencies: [
                .product(name: "libwebp", package: "libwebp-Xcode"),
            ]
        ),
    ]
)
