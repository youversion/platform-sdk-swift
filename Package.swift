// swift-tools-version: 6.0

import PackageDescription

var products: [Product] = []
var targets: [Target] = [
    .target(
        name: "YouVersionPlatformCore"
    ),
    .testTarget(
        name: "YouVersionPlatformCoreTests",
        dependencies: ["YouVersionPlatformCore"],
        resources: [.process("Fixtures/bible_206.json")]
    ),
]

#if !os(Linux)
targets.append(
    .target(
        name: "YouVersionPlatformUI",
        dependencies: [
            .target(name: "YouVersionPlatformCore"),
        ],
        resources: [
            .process("Resources")
        ]
    )
)
targets.append(
    .target(
        name: "YouVersionPlatformReader",
        dependencies: [
            .target(name: "YouVersionPlatformUI"),
        ],
        resources: [
            .process("Resources")
        ]
    )
)
targets.append(
    .testTarget(
        name: "YouVersionPlatformUITests",
        dependencies: ["YouVersionPlatformUI"]
    )
)
targets.append(
    .target(
        name: "YouVersionPlatform",
        dependencies: [
            .target(name: "YouVersionPlatformCore"),
            .target(name: "YouVersionPlatformUI"),
            .target(name: "YouVersionPlatformReader"),
        ],
        path: "Sources/YouVersionPlatformAll"
    )
)
products.append(
    .library(
        name: "YouVersionPlatform",
        targets: ["YouVersionPlatform"]
    )
)
#else
products.append(
    .library(
        name: "YouVersionPlatformCore",
        targets: ["YouVersionPlatformCore"]
    )
)
#endif

let package = Package(
    name: "YouVersionPlatform",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: products,
    targets: targets
)
