// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LittleBlueTooth",
    platforms: [
        // Add support for all platforms starting from a specific version.
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "LittleBlueTooth",
            targets: ["LittleBlueTooth"]),
        .library(
            name: "LittleBlueToothForTest",
            targets: ["LittleBlueToothForTest"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "CoreBluetoothMock",
                 url: "https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock.git",
                 .upToNextMinor(from: "0.12.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "LittleBlueTooth",
            dependencies: []),
        .target(
            name: "LittleBlueToothForTest",
            dependencies: ["CoreBluetoothMock"],
            swiftSettings: [.define("TEST")]
        ),
        .testTarget(
            name: "LittleBlueToothTests",
            dependencies: ["LittleBlueToothForTest","CoreBluetoothMock"])
    ],
    swiftLanguageVersions: [.v5]
)
