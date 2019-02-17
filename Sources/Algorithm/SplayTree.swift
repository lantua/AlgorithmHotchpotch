//
//  SplayTree.swift
//  Algorithm
//
//  Created by Natchanon Luangsomboon on 14/2/2562 BE.
//  Copyright © 2562 Natchanon Luangsomboon. All rights reserved.
//

public struct SplayTree<Key, Value> where Key: Comparable {
    private class Node {
        var key: Key, value: Value
        var left, right: Node?

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }

        subscript(direction: Direction) -> Node? {
            get {
                switch direction {
                case .left: return left
                case .right: return right
                }
            }
            set {
                switch direction {
                case .left: left = newValue
                case .right: right = newValue
                }
            }
        }
    }
    private enum Direction {
        case left, right

        var opposite: Direction {
            switch self {
            case .left: return .right
            case .right: return .left
            }
        }
    }

    private var root: Node?

    public init() { }

    public func list() -> [(Key, Value)] {
        var result: [(Key, Value)] = []

        func traverse(node: Node?) {
            guard let node = node else {
                return
            }
            traverse(node: node.left)
            result.append((node.key, node.value))
            traverse(node: node.right)
        }

        traverse(node: root)
        return result
    }

    public mutating func min() -> Key? {
        SplayTree.splay(root: &root) { _ in .left }
        return root?.key
    }
    public mutating func max() -> Key? {
        SplayTree.splay(root: &root) { _ in .right }
        return root?.key
    }
    
    public subscript(key: Key) -> Value? {
        mutating get {
            seek(key)
            return root?.key == key ? root!.value : nil
        }
        set {
            seek(key)

            if let newValue = newValue {
                if root?.key == key {
                    root!.value = newValue
                } else {
                    let node = Node(key: key, value: newValue)
                    defer { root = node }

                    guard let p = root else {
                        return
                    }

                    let direction = p.key < key ? Direction.left : .right

                    node[direction] = p
                    swap(&node[direction.opposite], &p[direction.opposite])
                }
            } else {
                if root?.key == key {
                    let right = root?.right
                    root = root?.left
                    if root != nil {
                        _ = max()
                        root!.right = right
                    } else {
                        root = right
                    }
                } else {
                    return
                }
            }
        }
    }

    private mutating func seek(_ key: Key) {
        SplayTree.splay(root: &root) { current in
            if current < key {
                return .right
            }
            if current > key {
                return .left
            }
            return nil
        }
    }

    private static func splay(root: inout Node!, direction: (Key) -> Direction?) {
        guard root != nil,
            let direction = SplayTree.splay(node: &root, direction: direction) else {
                return
        }

        let x = root[direction]!

        root[direction] = x[direction.opposite]

        x[direction.opposite] = root

        root = x
    }
    private static func splay(node: inout Node, direction: (Key) -> Direction?) -> Direction? {
        guard let currentDirection = direction(node.key),
            node[currentDirection] != nil else {
                return nil
        }

        guard let childDirection = splay(node: &node[currentDirection]!, direction: direction) else {
            return currentDirection
        }

        let p = node[currentDirection]!, x = p[childDirection]!

        if currentDirection == childDirection {
            node[currentDirection] = p[currentDirection.opposite]
            p[currentDirection.opposite] = node
        } else {
            node[currentDirection] = x[currentDirection.opposite]
            x[currentDirection.opposite] = node
        }

        p[childDirection] = x[childDirection.opposite]
        x[childDirection.opposite] = p
        node = x

        return nil
    }
}
