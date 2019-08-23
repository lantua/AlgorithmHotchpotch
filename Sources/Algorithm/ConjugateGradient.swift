private func dot(_ a: [Float], _ b: [Float]) -> Float {
    assert(a.count == b.count)
    return zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
}
private func product(_ sparse: [(row: Int, column: Int, Float)], _ vector: [Float], n: Int) -> [Float] {
    var result = [Float](repeating: 0, count: n)
    for (row, column, a) in sparse {
        result[row] += a * vector[column]
    }
    return result
}

/// Iteratively minimize 1/2 x^T A x - x^T b over `x`
public struct ConjugateGradient: Sequence {
    public struct Iterator: IteratorProtocol {
        private let base: ConjugateGradient

        private var x, p, r: [Float], sosR: Float

        fileprivate init(base: ConjugateGradient, x: [Float]) {
            self.base = base
            self.x = x

            let ax = product(base.A, x, n: base.n)
            r = zip(base.b, ax).map(-)
            p = r
            sosR = dot(r, r)
        }

        public mutating func next() -> [Float]? {
            guard sosR >= base.threshold else {
                return nil
            }

            let ap = product(base.A, p, n: base.n)
            let alpha = sosR / dot(p, ap)

            x = zip(x, p).map { $0 + alpha * $1 }
            r = zip(r, ap).map { $0 - alpha * $1 }

            let newSOSR = dot(r, r), beta = newSOSR / sosR
            
            p = zip(r, p).map { $0 + beta * $1 }
            sosR = newSOSR

            return x
        }
    }

    /// A sparse matrix in form of array of (row, column, value).
    public var A: [(row: Int, column: Int, value: Float)]
    public var b: [Float]
    /// Starting point for the conjugate gradient algorithm, or nil for zero vector.
    public var x0: [Float]?
    /// The stopping condition is when norm2(b - Ax)^2 < threshold.
    public var threshold: Float = 1e-10

    private var n: Int { return b.count }

    public __consuming func makeIterator() -> Iterator {
        return .init(base: self, x: x0 ?? [Float](repeating: 0, count: n))
    }
}
