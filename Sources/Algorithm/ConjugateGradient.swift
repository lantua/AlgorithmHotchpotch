private func dot(_ a: [Float], _ b: [Float]) -> Float {
    assert(a.count == b.count)
    return zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
}

public class ConjugateGradient {
    private let A: [(Int, Int, Float)], b: [Float], n: Int

    private var x, p, r: [Float], sosR: Float

    public init(A: [(Int, Int, Float)], b: [Float], x: [Float]? = nil) {
        self.n = b.count
        self.A = A
        self.b = b

        let x = x == nil ? [Float](repeating: 0, count: n) : x!
        self.x = x

        do {
            var ax = [Float](repeating: 0, count: n)
            for a in A {
                ax[a.0] += a.2 * x[a.1]
            }
            r = zip(b, ax).map { $0 - $1 }
            p = r
            sosR = dot(r, r)
        }
    }

    public func nextX() -> [Float] {
        var ap = [Float](repeating: 0, count: n)
        for (i, j, a) in A {
            ap[i] = a * p[j]
        }
        let pap = dot(p, ap)

        let alpha = sosR / pap

        let newX = zip(x, p).map { $0 + alpha * $1 }
        let newR = zip(r, ap).map { $0 - alpha * $1 }
        let newSOSR = dot(newR, newR)

        let beta = newSOSR / sosR
        let newP = zip(newR, p).map { $0 + beta * $1 }

        x = newX
        p = newP
        r = newR
        sosR = newSOSR

        return newX
    }
}
