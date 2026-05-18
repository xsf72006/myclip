// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "myclip",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "myclip", targets: ["myclip"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "myclip",
            dependencies: [
                .product(name: "HotKey", package: "HotKey")
            ],
            path: "Sources/myclip"
        )
    ]
)
