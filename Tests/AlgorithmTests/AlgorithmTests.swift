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

    func testMergeCollectionDifference() {
        do {
            let v1 = [6, 1, 2, 4, 5]
            let v2 = [3, 4, 5, 1, 2]
            let v3 = [1, 2, 3, 4, 7]

            var diff1 = v2.difference(from: v1)
            diff1 = diff1.inferringMoves()
            var diff2 = v3.difference(from: v2)
            diff2 = diff2.inferringMoves()

            let diff = diff1.combining(with: diff2)
            let result = v1.applying(diff)

            XCTAssertEqual(v3, result)
        }
    }

    func testSpectralLayout() {
        continueAfterFailure = false
        
        enum GraphID: Hashable {
            case a, b, c
        }

        let nodeCount = 6, dimension = 3
        let graphWeights = [GraphID.a: 0.5 as Float, .b: 0.7, .c: 1]
        var edges = [
            GraphID.a: [Edge(0, 2), .init(1, 4), .init(4, 3)] as Set,
            .b: [.init(0, 3), .init(2, 4), .init(2, 1), .init(2, 3)],
            .c: [.init(5, 0), .init(1, 5), .init(2, 5), .init(5, 3), .init(4, 5)]
        ]

        var layout = SpectralLayout(graphWeights: graphWeights, dimension: dimension, nodeCount: 2)
        layout.bounds[0] = 2
        layout.bounds[1] = 1.4
        for i in (0..<nodeCount).dropFirst(2) {
            let node = layout.addNode()
            XCTAssertEqual(i, node)
        }

        struct Edge: Hashable {
            var first: Int, second: Int
            init(_ first: Int, _ second: Int) {
                self.first = first
                self.second = second
            }
        }
        func listEdges() -> [GraphID: Set<Edge>] {
            return layout.listEdges().mapValues { Set($0.map { Edge($0.0, $0.1) }) }
        }

        do { // Set up edges
            for (graph, edges) in edges {
                for edge in edges {
                    layout.attach(edge.first, edge.second, graph: graph)
                }
            }
        }
        XCTAssertEqual(listEdges(), edges)
        while let id = layout.advance() {
            let newValue = layout.positions[id]
            XCTAssertEqual(max(-newValue.min()!, newValue.max()!), layout.bounds[id], accuracy: 1e-2)
        }

        do { // Check against known answer
            let answer = [
                [-2.0 as Float, 1.92215795, 0.29370346, -1.30115228, 1.0801786, -0.00584411],
                [ 0.9338186, 1.11133187, 0.04254553, -0.91637131, -1.4, 0.35699637],
                [-0.10932717, -0.06994587, 1.0, 0.06691563, -0.34443078, -0.49393831],
            ]

            for (answer, position) in zip(answer, layout.positions) {
                let flip = answer.first!.sign != position.first!.sign
                for (a, p) in zip(answer, position) {
                    if flip {
                        XCTAssertEqual(a, -p, accuracy: 1e-4)
                    } else {
                        XCTAssertEqual(a, p, accuracy: 1e-4)
                    }
                }
            }
        }

        do { // Re-attach edges, and detach non-existent edge
            for (graph, edges) in edges {
                for edge in edges {
                    layout.attach(edge.first, edge.second, graph: graph)
                }
            }
            layout.detach(4, 2, graph: .b)
        }
        XCTAssertEqual(listEdges(), edges)
        XCTAssertNil(layout.advance())
        XCTAssertNil(layout.advance())
        XCTAssertNil(layout.advance())

        do { // Remove edge
            edges[.b]!.remove(Edge(2, 3))
            layout.detach(2, 3, graph: .b)
        }
        XCTAssertEqual(listEdges(), edges)
        while let id = layout.advance() {
            let newValue = layout.positions[id]
            XCTAssertEqual(max(-newValue.min()!, newValue.max()!), layout.bounds[id], accuracy: 1e-2)
        }

        layout[node: 3] = [0, 1, .nan]
        do { // Remove node 1, 5 ~> 1
            layout.attach(1, 2, graph: .a)
            let oldPosition = layout[node: 5]
            XCTAssertEqual(layout.removeNode(at: 1), 5)
            XCTAssertEqual(layout[node: 1], oldPosition)

            edges = edges.mapValues {
                Set($0.compactMap {
                    guard $0.first != 1 && $0.second != 1 else {
                        return nil
                    }
                    let newFirst = $0.first == 5 ? 1 : $0.first
                    let newSecond = $0.second == 5 ? 1 : $0.second
                    return Edge(newFirst, newSecond)
                })
            }
        }
        XCTAssertEqual(listEdges(), edges)
        while let id = layout.advance() {
            let newValue = layout.positions[id]
            XCTAssertEqual(max(abs(newValue.min()!), abs(newValue.max()!)), layout.bounds[id], accuracy: 1e-2)
        }

        do { // Remove node 4
            layout.detach(4, 3, graph: .a)
            XCTAssertNil(layout.removeNode(at: 4))
            edges = edges.mapValues {
                Set($0.filter { $0.first != 4 && $0.second != 4 })
            }
        }
        XCTAssertEqual(listEdges(), edges)
        while let id = layout.advance() {
            let newValue = layout.positions[id]
            XCTAssertEqual(max(-newValue.min()!, newValue.max()!), layout.bounds[id], accuracy: 1e-2)
        }
    }

    static var allTests = [
        ("testSampler", testSampler),
        ("testHeap", testHeap),
        ("testDeBruijn", testDeBruijn),
        ("testConjugateGradient", testConjugateGradient),
        ("testSplayTree", testSplayTree),
        ("testSpectralLayout", testSpectralLayout),
    ]
}
