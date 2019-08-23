public struct MinHeap<Element> {
    private let isLessThan: (Element, Element) -> Bool
    private var values: [Element] = []

    public init(isLessThan: @escaping (Element, Element) -> Bool) {
        self.isLessThan = isLessThan
    }

    public var isEmpty: Bool { return values.isEmpty }
    public var min: Element? { return values.first }

    public mutating func insert(_ element: Element) {
        var current = values.count
        values.append(element)

        while current > 0 {
            let parent = (current - 1) / 2

            guard isLessThan(values[current], values[parent]) else {
                break
            }

            values.swapAt(parent, current)
            current = parent
        }
    }

    public mutating func popMin() {
        guard let last = values.popLast(),
            !values.isEmpty else {
            return
        }

        replaceMin(with: last)
    }

    /// Remove minimum value (if exists) and insert `element` in a single heap traversal
    public mutating func replaceMin(with element: Element) {
        guard !values.isEmpty else {
            values.append(element)
            return
        }
        values[0] = element

        var current = 0
        while true {
            let leftIndex = current * 2 + 1, rightIndex = leftIndex + 1

            guard leftIndex < values.count else {
                break
            }

            let child: Int
            if rightIndex >= values.count || isLessThan(values[leftIndex], values[rightIndex]) {
                child = leftIndex
            } else {
                child = rightIndex
            }

            guard isLessThan(values[child], values[current]) else {
                break
            }

            values.swapAt(child, current)
            current = child
        }
    }
}

extension MinHeap where Element: Comparable {
    public init() {
        self.init(isLessThan: <)
    }
}
