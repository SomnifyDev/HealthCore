// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HealthCore",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "HealthCore",
            targets: [
                "HealthCore",
                "HeartCore",
                "SleepCore",
                "WorkoutCore",
                "EnergyCore"
            ]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(
            name: "SomnifyDependencies",
            url: "https://github.com/Somnify/SomnifyDependencies.git",
            .branch("dev")
         )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "HealthCore",
            dependencies: [
                .product(name: "SomnifyDependencies", package: "SomnifyDependencies")
            ]
        ),
        .target(
            name: "HeartCore",
            dependencies: [
                "HealthCore",
                .product(name: "SomnifyDependencies", package: "SomnifyDependencies")
            ]
        ),
        .target(
            name: "EnergyCore",
            dependencies: [
                "HealthCore",
                .product(name: "SomnifyDependencies", package: "SomnifyDependencies")
            ]
        ),
        .target(
            name: "SleepCore",
            dependencies: [
                "HealthCore",
                .product(name: "SomnifyDependencies", package: "SomnifyDependencies")
            ]
        ),
        .target(
            name: "WorkoutCore",
            dependencies: [
                "HealthCore",
                "HeartCore",
                .product(name: "SomnifyDependencies", package: "SomnifyDependencies")
            ]
        )
    ]
)
