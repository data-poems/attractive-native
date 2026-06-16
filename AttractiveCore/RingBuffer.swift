import Foundation

/// Fixed-capacity ring buffer. Appends are O(1) with no per-append allocation
/// once warmed, replacing the O(n) `Array.removeFirst` that the trail used to
/// pay every frame. Ordered (oldest→newest) traversal is provided for consumers
/// that need the trajectory in time order (the 2D path and the SceneKit
/// geometry uploader).
public struct RingBuffer<T> {
    public let capacity: Int
    private var storage = ContiguousArray<T>()
    /// Index of the oldest element once the buffer is full (also the next write
    /// slot). Meaningless until `count == capacity`.
    private var writeIndex = 0

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        storage.reserveCapacity(self.capacity)
    }

    public var count: Int { storage.count }
    public var isFull: Bool { storage.count >= capacity }

    public mutating func append(_ element: T) {
        if storage.count < capacity {
            storage.append(element)
            writeIndex = storage.count % capacity
        } else {
            storage[writeIndex] = element
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    public mutating func removeAll(keepingCapacity: Bool = true) {
        storage.removeAll(keepingCapacity: keepingCapacity)
        writeIndex = 0
    }

    /// Apply `body` to each element oldest→newest. No allocation.
    @inline(__always)
    public func forEachOrdered(_ body: (T) -> Void) {
        let n = storage.count
        guard n > 0 else { return }
        let start = n < capacity ? 0 : writeIndex
        for i in 0..<n {
            body(storage[(start + i) % capacity])
        }
    }

    /// The buffer as an ordered array (oldest→newest). Allocates; prefer
    /// `forEachOrdered` on hot paths.
    public func ordered() -> [T] {
        var out = [T]()
        out.reserveCapacity(storage.count)
        forEachOrdered { out.append($0) }
        return out
    }

    /// The most-recently appended element, or nil if empty.
    public var last: T? {
        guard !storage.isEmpty else { return nil }
        let idx = (writeIndex + capacity - 1) % capacity
        return storage[idx]
    }
}

extension RingBuffer: Sendable where T: Sendable {}
