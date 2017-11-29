// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "AnyCodable",
    products:[
        .library(
            name: "AnyCodable", 
            targets:["AnyCodable"]
        )
    ],
    targets: [
        .target(name: "AnyCodable", path: "Sources"),
    ],
    swiftLanguageVersions: [4]
)
