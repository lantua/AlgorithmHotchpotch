private func share<ID>(underfull: inout (ID, ID, formerChance: Float), overfull: ID, chance: inout Float, average: Float) {
    assert(underfull.formerChance <= average && chance >= average)

    underfull.1 = overfull
    chance += underfull.formerChance - average
}

/// Randomly pick `ID`, each with different weight.
public struct Sampler<ID> {
    private var data: [(ID, ID, formerChance: Float)], average: Float

    public init<S: Sequence>(_ data: S) where S.Element == (ID, Float) {
        self.init(raw: data.map { ($0.0, $0.0, $0.1) })
    }

    private init(raw: [(ID, ID, formerChance: Float)]) {
        precondition(raw.allSatisfy { $0.formerChance >= 0 })
        data = raw
        average = data.map { $0.formerChance }.reduce(0, +) / Float(data.count)

        guard average > 0 else {
            data = []
            return
        }

        let overfullIndices: Range<Int>
        var underfullIndices: Range<Int>
        do {
            let pivot = data.partition { $0.formerChance > average }

            guard pivot > data.startIndex else {
                // This should never execute, but on an off-chance that
                // rounding error leads us here, we'd still be safe.
                return
            }

            overfullIndices = data[pivot...].indices
            underfullIndices = data[..<pivot].indices
        }

        for overfullIndex in overfullIndices {
            let id: ID
            var value: Float
            (id, _, value) = data[overfullIndex]
            defer {
                data[overfullIndex].formerChance = value
            }

            share(underfull: &data[data.index(before: overfullIndex)], overfull: id, chance: &value, average: average)

            while value > average,
                !underfullIndices.isEmpty {
                    share(underfull: &data[underfullIndices.removeFirst()], overfull: id, chance: &value, average: average)
            }
        }
    }

    public var isEmpty: Bool {
        return data.isEmpty
    }

    public func sample() -> ID? {
        guard let (former, latter, formerChance) = data.randomElement() else {
            return nil
        }

        return Float.random(in: 0...average) < formerChance ? former : latter
    }
}

extension Sampler where ID == Int {
    public init<S: Sequence>(enumerating input: S) where S.Element == Float {
        self.init(raw: input.enumerated().map { ($0.offset, $0.offset, $0.element) })
    }
}
