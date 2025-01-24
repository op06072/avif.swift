// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "avif",
    platforms: [.iOS(.v13), .macOS(.v12), .macCatalyst(.v14), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(
            name: "avif",
            targets: ["avif"]),
        .library(
            name: "avifnuke",
            targets: ["avifnuke"]),
        .library(
            name: "SDWebImageAVIF"
            , targets: ["SDWebImageAVIF"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", "12.0.0"..<"13.0.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", branch: "master"),
        .package(url: "https://github.com/SDWebImage/libavif-Xcode.git", from: "0.11.1")
    ],
    targets: [
        .target(
            name: "avifnuke",
            dependencies: [
                "avif", "avifc",
                .product(name: "Nuke", package: "Nuke")
            ]),
        .target(
            name: "avif",
            dependencies: ["avifc"]),
        .target(name: "avifc",
                dependencies: [
                    .product(name: "libavif", package: "libavif-Xcode"),
                    .product(name: "SDWebImage", package: "SDWebImage"),
                ],
                publicHeadersPath: "include",
                cxxSettings: [
                    .headerSearchPath("."),
                    .define("DEBUG", to: "1"),
                    .unsafeFlags(["-lm"]),
                ],
                linkerSettings: [
                    .linkedFramework("Accelerate")
                ]),
        .target(name: "SDWebImageAVIF",
                dependencies: [
                    "SDWebImage",
                    "avifc",
                    "avif"
                ]),
    ],
    cxxLanguageStandard: .cxx20
)
