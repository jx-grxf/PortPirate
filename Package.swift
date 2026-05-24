// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "PortPirate",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "PortPirate", targets: ["PortPirate"]),
    .library(name: "PortPirateCore", targets: ["PortPirateCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.2")
  ],
  targets: [
    .target(
      name: "PortPirateCore",
      dependencies: [
        .product(name: "Sparkle", package: "Sparkle")
      ],
      path: "Sources/PortPirateCore"
    ),
    .executableTarget(
      name: "PortPirate",
      dependencies: ["PortPirateCore"],
      path: "Sources/PortPirateApp"
    ),
    .testTarget(
      name: "PortPirateCoreTests",
      dependencies: ["PortPirateCore"],
      path: "Tests/PortPirateCoreTests"
    )
  ]
)
