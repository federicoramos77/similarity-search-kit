//
//  File.swift
//  SimilaritySearchKit
//
//  Created by Federico G. Ramos on 30.08.25.
//

import Foundation
import Testing
@testable import SimilaritySearchKit

@Suite(.serialized)
class MMRTests {
    
    // MARK: - Helpers
    private func n(_ v: [Float]) -> [Float] {
        // L2 normalize, guard zero norm
        let s = v.reduce(0) { $0 + $1*$1 }
        if s == 0 { return v }
        let inv = 1 / Float(s).squareRoot()
        return v.map { $0 * inv }
    }
    
    // MARK: - Basic behavior
    @Test
    func testSelectIndices_basicCosine() throws {
        // Given unit vectors on axes; query along x-axis
        let query = n([1, 0])
        let docs  = [n([1, 0]), n([0.9, 0.1]), n([0, 1])]
        
        // When: lambda = 1 behaves like pure relevance
        let k2 = 2
        let pure = try MMR.selectIndices(
            queryEmbedding: query,
            documentEmbeddings: docs,
            lambda: 1.0,
            topK: k2
        )
        
        // Then: top-2 by cosine are doc0, doc1
        #expect(pure == [0, 1])
        
        // When: stronger diversity
        let diverse = try MMR.selectIndices(
            queryEmbedding: query,
            documentEmbeddings: docs,
            lambda: 0.2,
            topK: k2
        )
        
        // Then: first is doc0, second should diversify to doc2 (orthogonal)
        #expect(diverse == [0, 2])
    }
    
    // MARK: - Parameter validation
    @Test
    func testSelectIndices_invalidLambda_throws() {
        let q: [Float] = [1.0, 0.0]
        let d: [[Float]] = [[1.0, 0.0]]
        #expect(throws: MMRError.invalidLambda) {
            _ = try MMR.selectIndices(
                queryEmbedding: q,
                documentEmbeddings: d,
                lambda: 1.5,
                topK: 1
            )
        }
    }
    
    @Test
    func testSelectIndices_invalidDimensions_throws() {
        let q: [Float] = [1.0, 0.0]
        let d: [[Float]] = [[1.0], [0.0, 1.0]] // mismatched
        #expect(throws: MMRError.invalidDimensions) {
            _ = try MMR.selectIndices(
                queryEmbedding: q,
                documentEmbeddings: d,
                lambda: 0.7,
                topK: 1
            )
        }
    }
    
    // MARK: - Deterministic tie-breaking
    @Test
    func testSelectIndices_tieBreaksByLowerIndex() throws {
        // Construct docs equidistant and mutually equidistant to force equal MMR scores
        let q = n([1, 1])
        let docs = [n([1, 1]), n([1, 1])] // identical
                                          // Both candidates identical; first pick is 0, second must be 1
        let picked = try MMR.selectIndices(
            queryEmbedding: q,
            documentEmbeddings: docs,
            lambda: 0.5,
            topK: 2
        )
        #expect(picked == [0, 1])
    }
    
    // MARK: - Rerank convenience
    @Test
    func testRerankAll_matchesSelectIndices() throws {
        let q = n([0.6, 0.8])
        let docs = [n([1, 0]), n([0.7, 0.7]), n([0, 1])]
        let a = try MMR.selectIndices(
            queryEmbedding: q,
            documentEmbeddings: docs,
            lambda: 0.6,
            topK: docs.count
        )
        let b = try MMR.rerankAll(
            queryEmbedding: q,
            documentEmbeddings: docs,
            lambda: 0.6
        )
        #expect(a == b)
    }
    
    // MARK: - NaN safety for custom similarity
    @Test
    func testSelectIndices_nanFromSimilarityTreatedAsNegInf() throws {
        let q = n([1, 0])
        let docs = [n([1, 0]), n([0, 1])]
        // Custom similarity that returns NaN for doc 0
        let sim: ([Float],[Float]) -> Float = { a, b in
            if b[0] > 0.9 { return .nan }
            // standard dot on normalized vectors == cosine
            var s: Float = 0
            for i in 0..<a.count { s += a[i]*b[i] }
            return s
        }
        let picked = try MMR.selectIndices(
            queryEmbedding: q,
            documentEmbeddings: docs,
            lambda: 1.0,
            topK: 1,
            similarity: sim
        )
        // Since NaN -> -inf, it should avoid doc 0 and pick doc 1
        #expect(picked == [1])
    }
    
    // MARK: - Edge cases
    @Test
    func testSelectIndices_emptyOrZeroTopK_returnsEmpty() throws {
        let q: [Float] = [1, 0]
        let d: [[Float]] = []
        let res1 = try MMR.selectIndices(
            queryEmbedding: q,
            documentEmbeddings: d,
            lambda: 0.7,
            topK: 5
        )
        #expect(res1.isEmpty)
        
        let docs:[[Float]] = [[1.0, 0.0]]
        let res2 = try MMR.selectIndices(queryEmbedding: q,
                                         documentEmbeddings: docs,
                                         lambda: 0.7,
                                         topK: 0
        )
        #expect(res2.isEmpty)
    }
}
