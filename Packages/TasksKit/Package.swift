// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TasksKit",
    platforms: [.iOS("16.0")],
    products: [
        .library(name: "TasksKit", targets: ["TasksKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.26.2")
    ],
    targets: [
        .target(
            name: "TasksKit",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        )
    ]
)
