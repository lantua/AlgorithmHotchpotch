//
//  MergeCollectionDifference.swift
//  
//
//  Created by Natchanon Luangsomboon on 1/1/2563 BE.
//

public extension CollectionDifference {
    /// Returns a new `CollectionDifference` whose application is equivalent to applying `self`, *then* `other`.
    func combining(with other: Self) -> Self {
        func offsets(of change: Self.Change) -> (offset: Int, associatedOffset: Int?) {
            switch change {
            case let .insert(offset, _, associatedOffset),
                 let .remove(offset, _, associatedOffset):
                return (offset, associatedOffset)
            }
        }

        func compute(near: [Change], far: [Change], queries: [Change]) -> [Int: (offset: Int, duplicated: Bool)] {
            var nearIterator = near.makeIterator(), farIterator = far.makeIterator(), nearCount = 0, farCount = 0
            var nearOffsets = nearIterator.next().map(offsets(of:)), farOffset = farIterator.next().map(offsets(of:))?.offset

            return Dictionary(uniqueKeysWithValues: queries.compactMap { query in
                let query = offsets(of: query).offset
                while let (offset, associatedOffset) = nearOffsets, offset <= query {
                    if offset == query {
                        return associatedOffset.map { (query, ($0, true)) }
                    }

                    nearCount += 1
                    nearOffsets = nearIterator.next().map(offsets(of:))
                }

                let partialResult = query - nearCount

                while let offset = farOffset, offset <= partialResult {
                    farCount += 1
                    farOffset = farIterator.next().map {
                        offsets(of: $0).offset - farCount
                    }
                }

                return (query, (partialResult + farCount, false))
            })
        }

        let secondRemovalMapping = compute(near: self.insertions, far: self.removals, queries: other.removals)
        let firstInsertionMapping = compute(near: other.removals, far: other.insertions, queries: self.insertions)

        var tmp: [Change] = []
        tmp.reserveCapacity(self.count + other.count)

        tmp.append(contentsOf: self.lazy.compactMap { change -> Change? in
            switch change {
            case let .remove(offset, element, associatedOffset):
                return .remove(offset: offset, element: element, associatedWith: associatedOffset.map { firstInsertionMapping[$0]?.offset } ?? nil)
            case let .insert(offset, element, associatedOffset):
                guard let (offset, duplicated) = firstInsertionMapping[offset],
                    !duplicated else {
                        return nil
                }
                return .insert(offset: offset, element: element, associatedWith: associatedOffset)
            }
        })
        tmp.append(contentsOf: other.lazy.compactMap { change -> Change? in
            switch change {
            case let .insert(offset, element, associatedOffset):
                return .insert(offset: offset, element: element, associatedWith: associatedOffset.map { secondRemovalMapping[$0]?.offset } ?? nil)
            case let .remove(offset, element, associatedOffset):
                guard let (offset, duplicated) = secondRemovalMapping[offset],
                    !duplicated else {
                        return nil
                }
                return .remove(offset: offset, element: element, associatedWith: associatedOffset)
            }
        })

        return Self(tmp)!
    }
}
