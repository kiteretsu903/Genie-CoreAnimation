// swift-tools-version: 5.9
import PackageDescription

let package = Package(
	name: "GenieWarpMesh",
	platforms: [.macOS(.v14)],
	products: [
		.library(name: "GenieWarpMesh", targets: ["GenieWarpMesh"]),
		.library(name: "CGSPrivate", targets: ["CGSPrivate"]),
        .executable(name: "GenieCADemo", targets: ["GenieCADemo"]),
	],
	targets: [
		.target(
			name: "CGSPrivate",
			path: "Sources/CGSPrivate",
			publicHeadersPath: "include"
		),
		.target(
			name: "GenieWarpMesh",
			dependencies: ["CGSPrivate"],
			path: "Sources/GenieWarpMesh",
			linkerSettings: [.linkedFramework("CoreGraphics")]
		),
        .executableTarget(name: "GenieCADemo", dependencies: ["GenieWarpMesh"], path: "Examples/GenieCADemo", resources: [.copy("Resources/glacier-blue.png")]),
        .testTarget(name: "GenieWarpMeshTests", dependencies: ["GenieWarpMesh"]),
	]
)
