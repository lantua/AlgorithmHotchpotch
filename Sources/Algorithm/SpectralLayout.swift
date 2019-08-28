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
    private var edgeWeights: [[Int: Float]], degrees: [Float], tmp: [Float], degreeSum: Float, dirtyList: Set<Int> = []
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
    public init(graphWeights: [GraphID: Float], dimension: Int, nodeCount: Int = 0, threshold: Float = 1e-5) {
        self.threshold = threshold

        graphs = graphWeights.mapValues { Graph(weight: $0, nodeCount: nodeCount) }

        edgeWeights = Array(repeating: [:], count: nodeCount)
        degrees = Array(repeating: 0, count: nodeCount)
        tmp = Array(repeating: .signalingNaN, count: nodeCount)
        degreeSum = 0

        bounds = Array(repeating: 1, count: dimension)
        positions = repeatElement((), count: dimension).map {
            repeatElement((), count: nodeCount).map { Float.random(in: -1...1) }
        }
    }

    /// Compute the next iteration
    /// - returns: The dimension that is updated, if any.
    public mutating func advance(dimension: Int? = nil) -> Int? {
        cleanup()

        guard convergedCount < positions.count else {
            return nil
        }
        let updating = dimension ?? (convergedCount + exponentialRandom() % (positions.count - convergedCount))
        let old = updating == convergedCount ? positions[updating] : nil

        center(&positions[updating], degrees: degrees, degreeSum: degreeSum)
        if converging {
            for other in 0..<convergedCount {
                orthogonalize(&positions[convergedCount], from: positions[other], degrees: degrees, tmp: &tmp)
            }
        } else if let other = (0..<updating).randomElement() {
            orthogonalize(&positions[updating], from: positions[other], degrees: degrees, tmp: &tmp)
        }

        update(&positions[updating], bound: bounds[updating])

        if let old = old {
            let new = positions[updating]

            if threshold > difference(old, new, degrees: degrees, tmp: &tmp) {
                if converging {
                    convergedCount += 1
                }
                converging.toggle()
            }
        }

        return updating
    }

    private func update(_ value: inout [Float], bound: Float) {
        let old = value

        for (first, edges) in edgeWeights.enumerated() {
            for (second, weight) in edges {
                value[first] += weight * old[second]
            }
        }

        value = value.map {
            $0.isFinite ? $0 : Float.random(in: -bound...bound)
        }
        rebound(&value, to: bound)
    }
}

public extension SpectralLayout {
    /// Position of the node at `nodeID`
    subscript(node nodeID: Int) -> [Float] {
        get { return positions.map { $0[nodeID] } }
        set {
            for i in positions.indices {
                positions[i][nodeID] = newValue[i]
            }
            convergedCount = 0
        }
    }

    /// Add a new node.
    /// - returns: `id` of the added node.
    mutating func addNode() -> Int {
        let nodeID = edgeWeights.count
        for graphID in graphs.keys {
            graphs[graphID]!.appendNode()
        }
        edgeWeights.append([:])
        degrees.append(0)
        tmp.append(0)

        for dimension in positions.indices {
            positions[dimension].append(Float.random(in: -bounds[dimension]...bounds[dimension]))
        }
        return nodeID
    }

    /// Remove node at `nodeID`.
    /// - returns: `id` of the node that is replaced by `node`.
    /// - Postcondition: Update `return value` -> `nodeID` on all external records.
    mutating func removeNode(at nodeID: Int) -> Int? {
        let lastID = edgeWeights.index(before: edgeWeights.endIndex)

        defer {
            for graphID in graphs.keys {
                graphs[graphID]!.removeLastNode()
            }
            for dimension in positions.indices {
                positions[dimension].removeLast()
            }

            edgeWeights.removeLast()
            degrees.removeLast()
            tmp.removeLast()
            dirtyList.remove(lastID)
        }

        var neighbours: Set<Int> = []
        for graphID in graphs.keys {
            neighbours.formUnion(graphs[graphID]!.removeEdges(connectedTo: nodeID))
        }
        assert(!neighbours.contains(nodeID))
        dirtyList.formUnion(neighbours)

        guard lastID != nodeID else {
            return nil
        }

        for graphID in graphs.keys {
            graphs[graphID]!.replaceWithLastNode(node: nodeID)
        }
        for (neighbour, _) in edgeWeights[lastID] where !dirtyList.contains(neighbour) {
            edgeWeights[neighbour][nodeID] = edgeWeights[neighbour].removeValue(forKey: lastID)!
        }
        degrees[nodeID] = degrees[lastID]
        if dirtyList.contains(lastID) {
            dirtyList.insert(nodeID)
        }
        for index in positions.indices {
            positions[index][nodeID] = positions[index][lastID]
        }
        return lastID
    }

    /// Add edge between `first` and `second` nodes in `graph` if it doesn't exist.
    mutating func attach(_ first: Int, _ second: Int, graph: GraphID) {
        precondition(first != second && graphs[graph] != nil)

        if graphs[graph]!.attach(first, second) {
            dirtyList.insert(first)
            dirtyList.insert(second)
        }
    }

    /// Remove edge between `first` and `second` nodes in `graph` if it exists.
    mutating func detach(_ first: Int, _ second: Int, graph: GraphID) {
        precondition(first != second && graphs[graph] != nil)

        if graphs[graph]!.detach(first, second) {
            dirtyList.insert(first)
            dirtyList.insert(second)
        }
    }
}

extension SpectralLayout {
    func listEdges() -> [GraphID: [(Int, Int)]] {
        for clean in 0..<degrees.count where !dirtyList.contains(clean) {
            assert((edgeWeights[clean], degrees[clean]) == computeCache(at: clean))
        }

        return graphs.mapValues {
            $0.outEdges.enumerated().flatMap { arg -> [(Int, Int)] in
                let (first, seconds) = arg
                return seconds.map { (first, $0) }
            }
        }
    }
}

private extension SpectralLayout {
    mutating func cleanup() {
        guard !dirtyList.isEmpty else {
            return
        }

        for dirty in dirtyList {
            (edgeWeights[dirty], degrees[dirty]) = computeCache(at: dirty)
        }
        degreeSum = degrees.reduce(0, +)

        dirtyList = []
        convergedCount = 0
    }

    private func computeCache(at nodeID: Int) -> (edgeWeight: [Int: Float], degree: Float) {
        let sum = graphs.values.map { Float($0.outEdges[nodeID].count + $0.inEdges[nodeID].count) * $0.weight }.reduce(0, +)

        var weights: [Int: Float] = [:]
        for graph in graphs.values {
            for other in graph.inEdges[nodeID] {
                weights[other, default: 0] += graph.weight
            }
            for other in graph.outEdges[nodeID] {
                weights[other, default: 0] += graph.weight
            }
        }

        return (weights.mapValues { $0 / sum }, sum)
    }
}

private struct Graph {
    let weight: Float
    var outEdges, inEdges: [Set<Int>]

    init(weight: Float, nodeCount: Int) {
        self.weight = weight
        outEdges = Array(repeating: [], count: nodeCount)
        inEdges = Array(repeating: [], count: nodeCount)
    }

    mutating func attach(_ first: Int, _ second: Int) -> Bool {
        assert(first != second)
        if outEdges[first].insert(second).inserted {
            inEdges[second].insert(first)
            return true
        }
        return false
    }

    mutating func detach(_ first: Int, _ second: Int) -> Bool {
        assert(first != second)
        if outEdges[first].remove(second) != nil {
            inEdges[second].remove(first)
            return true
        }
        return false
    }

    mutating func appendNode() {
        outEdges.append([])
        inEdges.append([])
    }

    mutating func removeLastNode() {
        inEdges.removeLast()
        outEdges.removeLast()
    }

    mutating func removeEdges(connectedTo node: Int) -> Set<Int> {
        var neighbours: Set<Int> = []
        for neighbour in outEdges[node] {
            inEdges[neighbour].remove(node)
            neighbours.insert(neighbour)
        }
        for neighbour in inEdges[node] {
            outEdges[neighbour].remove(node)
            neighbours.insert(neighbour)
        }
        inEdges[node] = []
        outEdges[node] = []
        return neighbours
    }

    mutating func replaceWithLastNode(node: Int) {
        assert(outEdges[node].isEmpty && inEdges[node].isEmpty)

        let lastID = outEdges.index(before: outEdges.endIndex)
        assert(lastID != node)

        for neighbour in outEdges[lastID] {
            inEdges[neighbour].remove(lastID)
            inEdges[neighbour].insert(node)
        }
        for neighbour in inEdges[lastID] {
            outEdges[neighbour].remove(lastID)
            outEdges[neighbour].insert(node)
        }

        outEdges.swapAt(node, lastID)
        inEdges.swapAt(node, lastID)
    }
}

private func difference(_ lhs: [Float], _ rhs: [Float], degrees: [Float], tmp: inout [Float]) -> Float {
    assert(lhs.count == rhs.count && lhs.count == degrees.count && lhs.count <= tmp.count)

    var mag = Float.signalingNaN
    vDSP_vsub(lhs, 1, rhs, 1, &tmp, 1, vDSP_Length(lhs.count))
    vDSP_maxmgv(tmp, 1, &mag, vDSP_Length(lhs.count))

    return mag
}

private func orthogonalize(_ value: inout [Float], from base: [Float], degrees: [Float], tmp: inout [Float]) {
    assert(value.count == base.count && value.count == degrees.count && value.count <= tmp.count)

    var numerator = Float.signalingNaN, denominator = Float.signalingNaN
    vDSP_vmul(base, 1, degrees, 1, &tmp, 1, vDSP_Length(value.count))
    vDSP_dotpr(value, 1, tmp, 1, &numerator, vDSP_Length(value.count))
    vDSP_dotpr(base, 1, tmp, 1, &denominator, vDSP_Length(value.count))

    let factor = -numerator / denominator
    vDSP_vsma(base, 1, [factor], value, 1, &value, 1, vDSP_Length(value.count))
}

private func center(_ values: inout [Float], degrees: [Float], degreeSum: Float) {
    assert(values.count == degrees.count)

    var center = Float.signalingNaN
    vDSP_dotpr(values, 1, degrees, 1, &center, vDSP_Length(values.count))
    vDSP_vsadd(values, 1, [-center / degreeSum], &values, 1, vDSP_Length(values.count))
}

private func rebound(_ values: inout [Float], to magnitude: Float.Magnitude) {
    assert(magnitude > 0)

    var mag = Float.signalingNaN
    vDSP_maxmgv(values, 1, &mag, vDSP_Length(values.count))
    vDSP_vsmul(values, 1, [magnitude / mag], &values, 1, vDSP_Length(values.count))
}
