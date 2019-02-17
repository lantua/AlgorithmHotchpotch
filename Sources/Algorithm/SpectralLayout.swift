import Accelerate

public protocol SpectralGraphDelegate: class {
    func moved(node: Any, to: [Float])
}

public class SpectralGraph<Node: Hashable> {
    private var nodes: [Node: Int] = [:]
    private var locations: [[Float]]
    public var bounds: [Float] {
        didSet {
            assert(bounds.count == locations.count)
            convergedCount = 0
        }
    }

    public weak var delegate: SpectralGraphDelegate?

    private var edges: [[(Int, Float)]] = [], degrees: [Float] = [], sumOfDegrees: Float = 0
    private var convergedCount = 0

    public init(dimension: Int) {
        locations = Array(repeating: [], count: dimension)
        bounds = Array(repeating: 1, count: dimension)
    }

    public func updateLocations() {
        notifyMoving(node: nil)
    }
}

private extension SpectralGraph {
    func notifyMoving(node: Node?) {
        if let node = node {
            let index = nodes[node]!
            delegate?.moved(node: node, to: locations.map { $0[index] })
        } else if let delegate = delegate {
            for (node, index) in nodes {
                delegate.moved(node: node, to: locations.map { $0[index] })
            }
        }
    }
}

public extension SpectralGraph {
    func advance() -> Bool {
        guard nodes.count > locations.count,
            convergedCount < locations.count else {
                return false
        }
        for k in convergedCount..<locations.count {
            update(dimension: k)
        }
        notifyMoving(node: nil)
        return true
    }

    private func update(dimension k: Int) {
        var location = locations[k]
        let vDSPNodeCount = vDSP_Length(location.count)

        do { // Orthogonalize
            // Center `location` at 0
            let factor = dot(location, degrees) / Float(sumOfDegrees)
            vDSP_vsadd(location, 1, [-factor], &location, 1, vDSPNodeCount)

            var tmpDU = Array(repeating: Float(), count: location.count)
            for baseLocation in locations.prefix(k) {
                // tmpDU[*] = baseLocation[*] * degrees[*]
                vDSP_vmul(baseLocation, 1, degrees, 1, &tmpDU, 1, vDSPNodeCount)
                let factor = dot(location, tmpDU) / dot(baseLocation, tmpDU)
                // locations[k][*] -= locations[l][*] * factor
                vDSP_vsma(baseLocation, 1, [-factor], location, 1, &location, 1, vDSPNodeCount)
            }
        }

        // Multiply with 1⁄2(I + D-1A)
        // newLocation[*] = location[*] + dot(outWeight[**], outNeighbour[**]) / degree[*]
        var newLocations = [Float](repeating: 0, count: nodes.count)
        for (id1, outEdges) in edges.enumerated() {
            for (id2, degree) in outEdges {
                newLocations[id1] += location[id2] * degree
                newLocations[id2] += location[id1] * degree
            }
        }
        vDSP_vdiv(degrees, 1, newLocations, 1, &newLocations, 1, vDSPNodeCount)
        vDSP_vadd(newLocations, 1, location, 1, &newLocations, 1, vDSPNodeCount)
        rebound(&newLocations, to: bounds[k])

        if k == convergedCount {
            var distance = Float.nan
            vDSP_distancesq(newLocations, 1, location, 1, &distance, vDSPNodeCount)
            if distance < 5e-9 * bounds[k] * bounds[k] * Float(nodes.count) {
                convergedCount += 1
            }
        }

        locations[k] = newLocations
    }
}

public extension SpectralGraph {
    func resetLocations() {
        locations = (0..<locations.count).map { i in
            repeatElement((), count: nodes.count).map {
                Float.random(in: -bounds[i]...bounds[i])
            }
        }

        notifyMoving(node: nil)
        convergedCount = 0
    }
    subscript(node: Node) -> [Float]? {
        get {
            guard let id = nodes[node] else {
                return nil
            }
            return locations.map { $0[id] }
        }
        set {
            if let id = nodes[node] {
                if let newValue = newValue {
                    for (i, newValue) in zip(locations.indices, newValue) {
                        locations[i][id] = newValue
                    }
                    notifyMoving(node: node)
                } else {
                    remove(node: node, id: id)
                }
            } else if let newValue = newValue {
                add(node: node, at: newValue)
            }

            convergedCount = 0
        }
    }

    func add(node: Node, at location: [Float]? = nil) {
        guard nodes[node] == nil else {
            return
        }

        let id = nodes.count
        nodes[node] = id
        for i in locations.indices {
            locations[i].append(location?[i] ?? Float.random(in: -bounds[i]...bounds[i]))
        }
        degrees.append(0)
        edges.append([])

        notifyMoving(node: node)
        convergedCount = 0
    }

    // Remove all (node, _) edges and replace them with (node, neighbours[*])
    func refreshHalfEdges<S: Sequence>(from node: Node, with neighbours: S) where S.Element == (Node, Float) {
        guard let nodeID = nodes[node] else {
            return
        }

        let neighbours = Dictionary(neighbours.compactMap { neighbour -> (Int, Float)? in
            guard let id = nodes[neighbour.0],
                id != nodeID else {
                    return nil
            }
            return (id, neighbour.1)
        }, uniquingKeysWith: +)

        removeEdgeDegree(from: nodeID)
        edges[nodeID] = neighbours.map { $0 }
        addEdgeDegree(from: nodeID)

        convergedCount = 0
    }
}

private extension SpectralGraph {
    func remove(node: Node, id: Int) {
        assert(nodes[node] != nil)

        if id == nodes.count - 1 {
            remove(lastNode: node)
        } else {
            replaceWithLastNode(node)
        }

        convergedCount = 0
    }

    func remove(lastNode: Node) {
        let deletingID = nodes.removeValue(forKey: lastNode)!
        assert(deletingID == nodes.count)

        for i in locations.indices {
            locations[i].removeLast()
        }

        removeEdgeDegree(from: deletingID)
        edges.removeLast()
        removeEdges(to: deletingID)
        degrees.removeLast()
    }

    func replaceWithLastNode(_ deletingNode: Node) {
        let deletingID = nodes.removeValue(forKey: deletingNode)!
        let lastID = nodes.count
        let lastNode = nodes.first(where: { $0.value == lastID })!.key
        nodes[lastNode] = deletingID

        assert(deletingID != lastID)

        for i in locations.indices {
            locations[i][deletingID] = locations[i].removeLast()
        }

        removeEdges(to: deletingID)
        removeEdgeDegree(from: deletingID)
        edges[deletingID] = edges.removeLast()
        degrees[deletingID] = degrees.removeLast()
        for i in edges.indices {
            edges[i] = edges[i].map {
                let id = $0.0 == lastID ? deletingID : $0.0
                return (id, $0.1)
            }
        }
    }
}

private extension SpectralGraph {
    func addEdgeDegree(from nodeID: Int) {
        var sum: Float = 0
        for (neighbour, degree) in edges[nodeID] {
            assert(neighbour != nodeID)
            degrees[neighbour] += degree
            sum += degree
        }
        degrees[nodeID] += sum
        sumOfDegrees += 2 * sum
    }

    func removeEdgeDegree(from nodeID: Int) {
        var sum: Float = 0
        for (neighbour, degree) in edges[nodeID] {
            assert(neighbour != nodeID)
            degrees[neighbour] -= degree
            sum += degree
        }
        degrees[nodeID] -= sum
        sumOfDegrees -= 2 * sum
    }
    func removeEdges(to nodeID: Int) {
        var sum: Float = 0
        for neighbour in edges.indices {
            edges[neighbour].removeAll {
                let (destination, degree) = $0
                if destination == nodeID {
                    assert(neighbour != nodeID)
                    degrees[neighbour] -= degree
                    sum += degree
                    return true
                }
                return false
            }
        }

        degrees[nodeID] -= sum
        sumOfDegrees -= 2 * sum
    }
}

private func dot(_ lhs: [Float], _ rhs: [Float]) -> Float {
    assert(lhs.count == rhs.count)
    var output: Float = 0
    vDSP_dotpr(lhs, 1, rhs, 1, &output, vDSP_Length(lhs.count))
    return output
}

private func rebound(_ values: inout [Float], to bound: Float) {
    assert(bound > 0)
    var magnitude: Float = 0
    vDSP_maxmgv(values, 1, &magnitude, vDSP_Length(values.count))
    vDSP_vsmul(values, 1, [bound / magnitude], &values, 1, vDSP_Length(values.count))
}
