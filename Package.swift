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
  targets: [
    .target(
      name: "MacDevCore",
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
