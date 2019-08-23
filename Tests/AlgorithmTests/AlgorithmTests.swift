import XCTest
@testable import Algorithm

final class AlgorithmTests: XCTestCase {
    func testSampler() {
        do {
            let values: [Float] = [0.1, 0.7, 0.3], sum = values.reduce(0, +)
            var stats = Array(repeating: 0, count: values.count)

            let sampler = Sampler(enumerating: values)
            let count = 100000
            for _ in 0..<count {
                stats[sampler.sample()!] += 1
            }

            XCTAssertEqual(Float(stats[0]) / Float(count), values[0] / sum, accuracy: 0.01)
            XCTAssertEqual(Float(stats[1]) / Float(count), values[1] / sum, accuracy: 0.01)
            XCTAssertEqual(Float(stats[2]) / Float(count), values[2] / sum, accuracy: 0.01)
        }
        do {
            let values: [Float] = [0, 0, 0]
            let sampler = Sampler(enumerating: values)

            XCTAssertTrue(sampler.isEmpty)
            XCTAssertNil(sampler.sample())
            XCTAssertNil(sampler.sample())
            XCTAssertNil(sampler.sample())
        }
        do {
            let values = [("foo", 1 as Float), ("bar", 1), ("test", 1)], sum = values.map { $0.1 }.reduce(0, +)
            var stats: [String: Int] = [:]
            let sampler = Sampler(values)

            let count = 100000
            for _ in 0..<count {
                stats[sampler.sample()!, default: 0] += 1
            }

            XCTAssertEqual(stats.count, 3)
            XCTAssertEqual(Float(stats[values[0].0]!) / Float(count), values[0].1 / sum, accuracy: 0.01)
            XCTAssertEqual(Float(stats[values[1].0]!) / Float(count), values[1].1 / sum, accuracy: 0.01)
            XCTAssertEqual(Float(stats[values[2].0]!) / Float(count), values[2].1 / sum, accuracy: 0.01)
        }
    }

    func testHeap() {
        let values = [0, 7, 5, 6, 4, 9, 3, 2, 2]
        let expected = [0, 2, 2, 3, 4, 5, 6, 7, 9]

        var heap = MinHeap<Int>()
        XCTAssertTrue(heap.isEmpty)

        for value in values {
            heap.insert(value)
        }

        XCTAssertFalse(heap.isEmpty)

        for value in expected {
            XCTAssertEqual(heap.min, value)
            heap.popMin()
        }

        XCTAssertTrue(heap.isEmpty)
        heap.replaceMin(with: -1)
        XCTAssertFalse(heap.isEmpty)
        XCTAssertEqual(heap.min, -1)
    }

    func testDeBruijn() {
        let alphabet = [1, -1, 0], length = 7
        let sequence = deBruijnSequence(of: alphabet, length: length)
        let loop = sequence + sequence.prefix(length - 1)

        var list: Set<[Int]> = []

        for i in sequence.indices {
            list.insert(Array(loop[i..<(i + length)]))
        }

        XCTAssertEqual(sequence.count, Int(pow(Double(alphabet.count), Double(length))))
        XCTAssertEqual(list.count, sequence.count)
        XCTAssertTrue(sequence.allSatisfy(alphabet.contains))
    }

    func testConjugateGradient() {
        let A: [(Int, Int, Float)] = [(0,0,1), (0,2,3), (2,0,3), (1,1,1), (2,2,18)]
        let b: [Float] = [1,3,2]
        let threshold: Float = 1e-11

        // norm(Ax - b)^2
        func norm(at x: [Float]) -> Float {
            // result = Ax - b
            var result = [Float](repeating: 0, count: x.count)
            for (row, column, a) in A {
                result[row] += x[column] * a
            }
            for (row, value) in b.enumerated() {
                result[row] -= value
            }

            return result.map { $0 * $0 }.reduce(0, +)
        }

        let sequence = ConjugateGradient(A: A, b: b, x0: nil, threshold: threshold)
        var oldNorm: Float?

        for value in sequence {
            let newNorm = norm(at: value)

            if let oldNorm = oldNorm {
                XCTAssertLessThan(newNorm, oldNorm)
            }

            oldNorm = newNorm
        }

        continueAfterFailure = false
        XCTAssertNotNil(oldNorm)
        XCTAssertLessThan(oldNorm!, threshold)
    }

    func testSplayTree() {
        let values = [0, 7, 5, 6, 4, 9, 3, 2, 2]
        let expected = Set(values).sorted()

        var tree = SplayTree<Int, String>()
        XCTAssertNil(tree.min())
        XCTAssertNil(tree.max())

        for value in values {
            tree[value] = String(value)
        }

        let result = tree.list()
        XCTAssertEqual(result.map { $0.0 }, expected)
        XCTAssertTrue(result.allSatisfy { String($0.0) == $0.1 })
        XCTAssertEqual(expected.first, tree.min())
        XCTAssertEqual(expected.last, tree.max())

        XCTAssertNil(tree[8])
        XCTAssertNil(tree[-1])
        XCTAssertNil(tree[11])
        for value in values {
            XCTAssertEqual(String(value), tree[value])
        }

        for value in values {
            tree[value] = nil
        }

        XCTAssertTrue(tree.list().isEmpty)
    }

    static var allTests = [
        ("testSampler", testSampler),
        ("testHeap", testHeap),
        ("testDeBruijn", testDeBruijn),
        ("testConjugateGradient", testConjugateGradient),
        ("testSplayTree", testSplayTree),
    ]
}
