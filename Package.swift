// swift-tools-version: 6.2
import PackageDescription

// gaea-plugin-rife: hzwer's Practical-RIFE 4.25 (MIT weights) as a Gaea plugin on MES Video
// 0.1's video.interpolate. One worker executable built on GaeaPluginKit over mlx-rife-swift, packaged as a
// signed .gaeaplugin by scripts/build-plugin.sh.
//
// rife-inproc is not part of the plugin: it runs the same package in-process through MLXServeEngine, with the same
// dependency resolution and requests, as the reference a run through Gaea is compared against.
//
// GAEA_PLUGIN_KIT_PATH points the kit at a local checkout while you work on both.
let kitPath = Context.environment["GAEA_PLUGIN_KIT_PATH"]

let package = Package(
    name: "gaea-plugin-rife",
    platforms: [.macOS(.v26)], // mlx-engine-swift's MLXToolKit requires macOS 26
    dependencies: [
        kitPath.map { .package(path: $0) }
            ?? .package(url: "https://github.com/xocialize-code/gaea-plugin-kit.git", from: "0.9.0"),
        .package(url: "https://github.com/xocialize/mlx-rife-swift.git", exact: "0.8.0"),
        .package(url: "https://github.com/xocialize/mlx-engine-swift.git", from: "0.73.1"),
    ],
    targets: [
        .target(
            name: "RIFEPlugin",
            dependencies: [
                .product(name: "GaeaPluginKit", package: "gaea-plugin-kit"),
                .product(name: "MLXRIFE", package: "mlx-rife-swift"),
                .product(name: "MLXToolKit", package: "mlx-engine-swift"),
            ]
        ),
        .executableTarget(
            name: "gaea-rife-worker",
            dependencies: [
                "RIFEPlugin",
                .product(name: "GaeaPluginKit", package: "gaea-plugin-kit"),
            ]
        ),
        .executableTarget(
            name: "rife-inproc",
            dependencies: [
                "RIFEPlugin",
                .product(name: "GaeaProtocol", package: "gaea-plugin-kit"),
                .product(name: "MLXRIFE", package: "mlx-rife-swift"),
                .product(name: "MLXToolKit", package: "mlx-engine-swift"),
                .product(name: "MLXServeCore", package: "mlx-engine-swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "RIFEPluginTests", dependencies: ["RIFEPlugin", .product(name: "MLXRIFE", package: "mlx-rife-swift")]),
    ]
)
