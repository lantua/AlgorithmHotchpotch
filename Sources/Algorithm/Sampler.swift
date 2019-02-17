public struct Sampler<ID: Hashable> {
    private var data: [(ID, ID, chanceOfFormer: Float)], average: Float

    public init<S: Sequence>(_ data: S) where S.Element == (ID, Float) {
        self.init(raw: data.map { ($0.0, $0.0, $0.1) })
    }

    private init(raw: [(ID, ID, chanceOfFormer: Float)]) {
        data = raw

        let sum = data.map { $0.chanceOfFormer } .reduce(0, +)
        average = sum / Float(data.count)

        let overFullIndices: Range<Int>
        var underFullIterator: IndexingIterator<Range<Int>>
        do {
            let underFullCount = data.partition { $0.chanceOfFormer > average }

            guard underFullCount > 0 else {
                return
            }

            let underFullIndices = data.indices.prefix(underFullCount - 1)
            overFullIndices = data.indices.suffix(from: underFullCount)
            underFullIterator = underFullIndices.makeIterator()
        }

        outer: for overFullIndex in overFullIndices {
            var overFullValue: Float
            let overFullKey: ID
            (overFullKey, _, overFullValue) = data[overFullIndex]

            do {
                let underFullIndex = overFullIndex - 1
                data[underFullIndex].1 = overFullKey

                overFullValue += data[underFullIndex].chanceOfFormer - average
            };

            while overFullValue > average {
                guard let underFullIndex = underFullIterator.next() else {
                    break outer
                }

                data[underFullIndex].1 = overFullKey
                overFullValue += data[underFullIndex].chanceOfFormer - average
            }

            data[overFullIndex].chanceOfFormer = overFullValue
        }
    }

    public var isEmpty: Bool {
        return data.isEmpty
    }

    public func sample() -> ID? {
        guard let (former, latter, chanceOfFormer) = data.randomElement() else {
            return nil
        }

        assert(0...average ~= chanceOfFormer || former == latter)
        return Float.random(in: 0...average) < chanceOfFormer ? former : latter
    }
}

extension Sampler where ID == Int {
    public init<S: Sequence>(enumerating input: S) where S.Element == Float {
        self.init(raw: input.enumerated().map { ($0.offset, $0.offset, $0.element) })
    }
}
