// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UIKitPlus",
	platforms: [
	.iOS("11.0"),
        .macOS(.v10_11),
        .tvOS(.v13)
	],
    products: [
        .library(name: "UIKitPlus", targets: ["UIKitPlus"]),
	],
    dependencies: [],
    targets: [
		.target(name: "UIKitPlus", dependencies: [], path: "Classes"),
	]
)
