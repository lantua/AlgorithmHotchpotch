func compareLatter<A, B: Comparable>(_ lhs: (A, B), _ rhs: (A, B)) -> Bool {
    return lhs.1 < rhs.1
}
