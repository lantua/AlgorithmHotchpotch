public struct MinHeap<Element> {
    private let isLessThan: (Element, Element) -> Bool
    private var values: [Element] = []

    public init(isLessThan: @escaping (Element, Element) -> Bool) {
        self.isLessThan = isLessThan
    }

    public var isEmpty: Bool { return values.isEmpty }

    public func min() -> Element? {
        return values.first
    }
    public mutating func insert(_ element: Element) {
        var current = values.count
        values.append(element)

        while current > 0 {
            let parent = (current - 1) / 2

            if isLessThan(values[current], values[parent]) {
                values.swapAt(parent, current)
                current = parent
            } else {
                break
            }
        }
    }

    public mutating func removeMin() {
        guard let last = values.popLast(),
            !values.isEmpty else {
            return
        }

        replaceMin(with: last)
    }

    /// Remove minimum value and insert `element` in a single heap traversal
    public mutating func replaceMin(with element: Element) {
        guard !values.isEmpty else {
            values.append(element)
            return
        }
        values[0] = element

        var current = 0
        while true {
            let leftIndex = current * 2 + 1, rightIndex = current * 2 + 2

            guard leftIndex < values.count else {
                break
            }

            let child: Int
            if rightIndex >= values.count || isLessThan(values[leftIndex], values[rightIndex]) {
                child = leftIndex
            } else {
                child = rightIndex
            }

            if isLessThan(values[child], values[current]) {
                values.swapAt(child, current)
                current = child
            } else {
                break
            }
        }
    }
}

extension MinHeap where Element: Comparable {
    public init() {
        self.init(isLessThan: <)
    }
}
