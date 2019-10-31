// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


import XCTest
@testable import AnyCodableTests

extension AnyCodableTests {
  static var allTests = [
    ("testDictionary", testDictionary),
    ("testArray", testArray),
    ("testSet", testSet),
    ("testTwoDimensionalArray", testTwoDimensionalArray),
    ("testUnregistredEncodingDecoding", testUnregistredEncodingDecoding),
  ]
}


XCTMain([
  testCase(AnyCodableTests.allTests),
])
