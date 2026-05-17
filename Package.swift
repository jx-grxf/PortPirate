// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "MacDev",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "MacDev", targets: ["MacDev"]),
    .library(name: "MacDevCore", targets: ["MacDevCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.2")
  ],
  targets: [
    .target(
      name: "MacDevCore",
      dependencies: [
        .product(name: "Sparkle", package: "Sparkle")
      ],
      path: "Sources/MacDevCore"
    ),
    .executableTarget(
      name: "MacDev",
      dependencies: ["MacDevCore"],
      path: "Sources/MacDevApp"
    ),
    .testTarget(
      name: "MacDevCoreTests",
      dependencies: ["MacDevCore"],
      path: "Tests/MacDevCoreTests"
    )
  ]
)
