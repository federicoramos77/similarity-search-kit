//
//  TopK.swift
//
//
//  Created by Bernhard Eisvogel on 31.10.23.
//

import Foundation

public extension Collection {
    /// Returns the top `count` elements from the collection in increasing order,
    /// using the provided comparison function.
    ///
    /// - Parameters:
    ///   - count: The maximum number of elements to return.
    ///   - by: A comparison closure that defines whether the first argument
    ///          should be ordered before the second.
    ///
    /// - Returns: An array of up to `count` elements, ordered by the given comparison.
    ///
    /// This implementation is optimized:
    /// * For small `count` relative to the collection size, it uses a partial
    ///   selection approach.
    /// * For large `count`, it falls back to a full stable sort.
    ///
    /// Ties are resolved stably: elements considered equal preserve their
    /// original order of appearance.
    func topK(_ count: Int, by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows -> [Self.Element] {
        assert(count >= 0,
           """
           Cannot prefix with a negative amount of elements!
           """)
        
        guard count > 0 else {
            return []
        }
        
        let prefixCount = Swift.min(count, self.count)
        
        guard prefixCount < self.count / 10 else {
            // For large results, use stable sort with original indices
            let indexedElements = self.enumerated().map { ($0.offset, $0.element) }
            let sortedWithIndices = try indexedElements.sorted { (lhs, rhs) in
                let compareResult = try areInIncreasingOrder(lhs.1, rhs.1)
                if compareResult { return true }
                let reverseResult = try areInIncreasingOrder(rhs.1, lhs.1)
                if reverseResult { return false }
                // Elements are equal, maintain original order
                return lhs.0 < rhs.0
            }
            return Array(sortedWithIndices.prefix(prefixCount).map { $0.1 })
        }
        
        // For small results, use the optimized approach with stable tie handling
        let initialPrefix = self.prefix(prefixCount)
        let indexedPrefix = initialPrefix.enumerated().map { ($0.offset, $0.element) }
        
        var result = try indexedPrefix.sorted { (lhs, rhs) in
            let compareResult = try areInIncreasingOrder(lhs.1, rhs.1)
            if compareResult { return true }
            let reverseResult = try areInIncreasingOrder(rhs.1, lhs.1)
            if reverseResult { return false }
            // Elements are equal, maintain original order
            return lhs.0 < rhs.0
        }
        
        var currentIndex = prefixCount
        for e in self.dropFirst(prefixCount) {
            if let last = result.last, try areInIncreasingOrder(last.1, e) {
                currentIndex += 1
                continue
            }
            
            // Find insertion point using stable partitioning
            let insertionIndex = try result.partition { (indexedElement) in
                let compareResult = try areInIncreasingOrder(e, indexedElement.1)
                if compareResult { return true }
                let reverseResult = try areInIncreasingOrder(indexedElement.1, e)
                if reverseResult { return false }
                // Elements are equal, new element should come after existing ones
                return false
            }
            
            let isLastElement = insertionIndex == result.endIndex
            result.removeLast()
            if isLastElement {
                result.append((currentIndex, e))
            } else {
                result.insert((currentIndex, e), at: insertionIndex)
            }
            
            currentIndex += 1
        }
        
        return result.map { $0.1 }
    }
}
