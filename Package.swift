// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FireSwiftData",
    
    platforms: [
        .iOS(.v13)
    ],
    
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FireSwiftData",
            targets: ["FireSwiftData"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FireSwiftData",
            dependencies: [.product(name: "FirebaseFirestore", package: "firebase-ios-sdk")]
        ),
        .testTarget(
            name: "FireSwiftDataTests",
            dependencies: ["FireSwiftData"]
        ),
    ]
)
