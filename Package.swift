// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuickReview",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "QuickReview",
            targets: ["QuickReview"]),
    ],
    targets: [
        .target(
            name: "QuickReview",
            dependencies: []),
        .testTarget(
            name: "QuickReviewTests",
            dependencies: ["QuickReview"]),
    ]
)
