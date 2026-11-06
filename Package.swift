// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OfflineImageGenerator",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OfflineImageGenerator",
            targets: ["OfflineImageGenerator"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/ml-stable-diffusion.git", from: "1.1.1")
    ],
    targets: [
        .executableTarget(
            name: "OfflineImageGenerator",
            dependencies: [
                .product(name: "StableDiffusion", package: "ml-stable-diffusion")
            ],
            path: "Sources/OfflineImageGenerator"
        )
    ]
)
