import XCTest
@testable import Algorithm

final class AlgorithmTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Algorithm().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
