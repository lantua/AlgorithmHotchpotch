import Accelerate

private var generator = SystemRandomNumberGenerator()
private func exponentialRandom() -> Int {
    return generator.next().trailingZeroBitCount
}

/// Spectral Layout Algorithm
/// Optimize the *aesthetic* function of the node location.
public struct SpectralLayout<GraphID: Hashable> {
    private let threshold: Float
    private var graphs: [GraphID: Graph]
    private var edgeWeights: [[Int: Float]], dirtyList: Set<Int>
    private var convergedCount = 0, converging = false

    /// The position of each node, arrange in positions[dimension][nodeIndex].
    public private(set) var positions: [[Float]]
    /// The maximum magnitude of each dimension, that is -bounds[k] <= locations[k][*] <= bounds[k].
    public var bounds: [Float] {
        didSet {
            precondition(bounds.count == positions.count && bounds.allSatisfy { $0 > 0 })
            convergedCount = 0
        }
    }

    /**
     - parameters:
        - graphWeights: Weight of each graph. This let us separate the entire graph into subgraphs, each with separate weight.
        - nodeCount: Maximum number of node.
        - dimension: Number of dimension to preserve.
        - threshold: Threshold to stop computing the next iteration.
     */
    public init(graphWeights: [GraphID: Float], nodeCount: Int, dimension: Int, threshold: Float = 1e-9) {
        self.threshold = threshold

        graphs = graphWeights.mapValues { Graph(weight: $0, count: nodeCount) }
        edgeWeights = Array(repeating: [:], count: nodeCount)
        dirtyList = []

        bounds = Array(repeating: 1, count: dimension)
        positions = repeatElement((), count: dimension).map {
            repeatElement((), count: nodeCount).map { Float.random(in: -1...1) }
        }
    }

    /// Add edge between `first` and `second` nodes in `graph` if it doesn't exist.
    public mutating func attach(_ first: Int, _ second: Int, graph: GraphID) {
        precondition(graphs[graph] != nil)

        if graphs[graph]!.attach(first, second) {
            dirtyList.insert(first)
            dirtyList.insert(second)
        }
    }

    /// Remove edge between `first` and `second` nodes in `graph` if it exists.
    public mutating func detach(_ first: Int, _ second: Int, graph: GraphID) {
        precondition(graphs[graph] != nil)

        if graphs[graph]!.detach(first, second) {
            dirtyList.insert(first)
            dirtyList.insert(second)
        }
    }

    /// Compute the next iteration
    /// - returns: The dimension that is updated, if any.
    public mutating func advance() -> Int? {
        cleanup()

        guard !converging else {
            // The lowest dimension is converging, lets orthogonalize it against all converged dimension.
            for other in 0..<convergedCount {
                orthogonalize(&positions[convergedCount], from: positions[other])
            }
            update(k: convergedCount)
            return convergedCount
        }

        let range = convergedCount..<positions.count

        guard !range.isEmpty,
            let k = range.dropFirst(exponentialRandom() % range.count).first else {
                return nil
        }
        if let other = (0..<k).randomElement() {
            orthogonalize(&positions[k], from: positions[other])
        }
        update(k: k)
        return k
    }

    private mutating func update(k: Int) {
        let old = positions[k]
        var new = old

        for (first, edges) in edgeWeights.enumerated() {
            for (second, weight) in edges {
                new[first] += weight * old[second]
                new[second] += weight * old[first]
            }
        }

        let validRange = -bounds[k]...bounds[k]
        new = new.map {
            $0.isFinite ? $0 : Float.random(in: validRange)
        }
        rebound(&new, to: bounds[k])

        if k == convergedCount {
            var distance: Float = .signalingNaN
            vDSP_distancesq(new, 1, old, 1, &distance, vDSP_Length(new.count))

            if sqrt(distance) / bounds[k] < threshold {
                if converging {
                    convergedCount += 1
                }
                converging.toggle()
            }
        }

        positions[k] = new
    }
}

private extension SpectralLayout {
    mutating func cleanup() {
        guard !dirtyList.isEmpty else {
            return
        }

        convergedCount = 0

        for dirty in dirtyList {
            let sum = graphs.values.map { Float($0.outEdges[dirty].count + $0.inEdges[dirty].count) * $0.weight }.reduce(0, +)

            var weights: [Int: Float] = [:]
            for graph in graphs.values {
                for other in graph.inEdges[dirty] {
                    weights[other, default: 0] += graph.weight
                }
                for other in graph.outEdges[dirty] {
                    weights[other, default: 0] += graph.weight
                }
            }

            edgeWeights[dirty] = weights.mapValues { $0 / sum }
        }

        dirtyList = []
    }
}

private struct Graph {
    let weight: Float
    var outEdges, inEdges: [Set<Int>]

    init(weight: Float, count: Int) {
        self.weight = weight
        outEdges = Array(repeating: [], count: count)
        inEdges = Array(repeating: [], count: count)
    }

    mutating func attach(_ first: Int, _ second: Int) -> Bool {
        precondition(first != second)
        if outEdges[first].insert(second).inserted {
            let inserted = inEdges[second].insert(first).inserted
            assert(inserted)
            return true
        }
        return false
    }

    mutating func detach(_ first: Int, _ second: Int) -> Bool {
        precondition(first != second)
        if outEdges[first].remove(second) != nil {
            let inserted = inEdges[second].insert(first).inserted
            assert(inserted)
            return true
        }
        return false
    }
}

private func orthogonalize(_ value: inout [Float], from base: [Float]) {
    assert(value.count == base.count)

    let factor = -dot(value, base) / dot(base, base)
    vDSP_vsma(base, 1, [factor], value, 1, &value, 1, vDSP_Length(value.count))
}

private func dot(_ lhs: [Float], _ rhs: [Float]) -> Float {
    assert(lhs.count == rhs.count)

    var output: Float = .signalingNaN
    vDSP_dotpr(lhs, 1, rhs, 1, &output, vDSP_Length(lhs.count))
    return output
}

private func rebound(_ values: inout [Float], to bound: Float) {
    assert(bound > 0)

    var magnitude: Float = .signalingNaN
    vDSP_maxmgv(values, 1, &magnitude, vDSP_Length(values.count))
    vDSP_vsmul(values, 1, [bound / magnitude], &values, 1, vDSP_Length(values.count))
}
