//
//  MMR.swift
//  SimilaritySearchKit
//
//  Created by Federico G. Ramos on 29.08.25.
//

import Foundation

public enum MMRError: Error {
    case invalidDimensions
    case invalidLambda
}

/// Implements Maximal Marginal Relevance (MMR) for re-ranking embeddings.
/// - Balances relevance to a query with diversity across selected documents.
/// - Supports different similarity functions (default: cosine).
/// - Normalization is enabled by default to ensure cosine-like behavior on arbitrary embeddings.
/// - Provides built-in helpers (`dotProduct`, `negativeEuclidean`) that can be passed as the `similarity` argument, but are not used by default.
final public class MMR {
    /// Select `topK` document indices using Maximal Marginal Relevance (MMR).
    /// By default, uses cosine similarity (with optional internal L2-normalization). You can provide a custom
    /// similarity function (e.g., dot-product, negative euclidean distance) via the `similarity` parameter.
    /// - Parameters:
    ///   - queryEmbedding: Embedding of the query. Length must match each document embedding length.
    ///   - documentEmbeddings: Embeddings of documents. Each must match the query vector length.
    ///   - lambda: Trade-off between relevance and diversity. 1.0 = only relevance, 0.0 = only diversity.
    ///   - topK: Number of indices to return. If `topK >= documentEmbeddings.count`, returns all indices re-ranked.
    ///   - normalize: If true (default), inputs are L2-normalized before scoring to ensure cosine similarity behavior.
    ///     Disable only if you deliberately want to use raw vector magnitudes.
    ///   - similarity: Optional custom similarity function. Defaults to cosine similarity. You can pass built-in helpers like `MMR.dotProduct` or `MMR.negativeEuclidean`.
    /// - Returns: Indices of selected documents in greedy MMR order.
    /// - Throws: `MMRError.invalidLambda` if `lambda` is outside 0...1. `MMRError.invalidDimensions` if vector lengths differ or are empty.
    public static func selectIndices(
        queryEmbedding: [Float],
        documentEmbeddings: [[Float]],
        lambda: Float = 0.7,
        topK: Int,
        normalize: Bool = true,
        similarity: (([Float], [Float]) -> Float)? = nil
    ) throws -> [Int] {
        guard !documentEmbeddings.isEmpty, topK > 0 else { return [] }
        guard (0...1).contains(lambda) else { throw MMRError.invalidLambda }
        
        let dimension = queryEmbedding.count
        guard dimension > 0, documentEmbeddings.allSatisfy({ $0.count == dimension }) else {
            throw MMRError.invalidDimensions
        }
        
        // This avoids coupling normalization to cosine-only logic, since custom similarities may also expect unit vectors.
        let normalizedQuery = normalize ? l2Normalize(queryEmbedding) : queryEmbedding
        let normalizedDocs = normalize ? documentEmbeddings.map(l2Normalize(_:)) : documentEmbeddings
        
        // NaN-safe similarity wrapper
        let safeSim: ([Float], [Float]) -> Float = { a, b in
            let value: Float
            if let sim = similarity { value = sim(a, b) } else { value = cosineSimilarity(a, b) }
            return value.isFinite ? value : -Float.infinity
        }
        
        // Precompute query–doc similarities
        let querySimilarities: [Float] = normalizedDocs.map { doc in
            safeSim(normalizedQuery, doc)
        }
        
        var selectedIndices: [Int] = []
        var remainingIndices: [Int] = Array(0..<normalizedDocs.count)
        let keepCount = min(topK, normalizedDocs.count)
        
        // Incremental cache of best diversity per candidate: max similarity to any selected doc so far
        var bestDiversity: [Float] = Array(repeating: 0, count: normalizedDocs.count)
        
        while selectedIndices.count < keepCount {
            var bestIndex: Int? = nil
            var bestMMRScore: Float = -Float.infinity
            
            for candidateIndex in remainingIndices {
                // Diversity term from incremental cache
                let diversityScore = bestDiversity[candidateIndex]
                
                let mmrScore = lambda * querySimilarities[candidateIndex] - (1 - lambda) * diversityScore
                if mmrScore > bestMMRScore || (mmrScore == bestMMRScore && (bestIndex == nil || candidateIndex < bestIndex!)) {
                    bestMMRScore = mmrScore
                    bestIndex = candidateIndex
                }
            }
            
            guard let pickedIndex = bestIndex else { break }
            selectedIndices.append(pickedIndex)
            if let removeAt = remainingIndices.firstIndex(of: pickedIndex) {
                remainingIndices.remove(at: removeAt)
            }
            
            // Update best diversity for remaining candidates with the newly selected document
            for c in remainingIndices {
                let s = safeSim(normalizedDocs[c], normalizedDocs[pickedIndex])
                if s > bestDiversity[c] { bestDiversity[c] = s }
            }
        }
        
        return selectedIndices
    }
    
    /// Re-rank all documents with MMR (no filtering). Equivalent to `selectIndices(..., topK: docs.count)`.
    /// - Parameters:
    ///   - normalize: If true (default), inputs are L2-normalized before scoring.
    /// - Returns: A permutation of all indices in MMR order.
    public static func rerankAll(
        queryEmbedding: [Float],
        documentEmbeddings: [[Float]],
        lambda: Float = 0.7,
        /// If true (default), inputs are L2-normalized before scoring.
        normalize: Bool = true,
        similarity: (([Float], [Float]) -> Float)? = nil
    ) throws -> [Int] {
        return try selectIndices(
            queryEmbedding: queryEmbedding,
            documentEmbeddings: documentEmbeddings,
            lambda: lambda,
            topK: documentEmbeddings.count,
            normalize: normalize,
            similarity: similarity
        )
    }
    
    // MARK: - Math helpers
    
    /// Cosine similarity for equal-length vectors. Assumes inputs are normalized if you want cosine in [-1,1].
    private static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return .nan }
        var dot: Float = 0
        for i in 0..<a.count { dot += a[i] * b[i] }
        return dot
    }
    
    /// L2-normalize a vector. If the norm is zero, returns the input unchanged.
    private static func l2Normalize(_ v: [Float]) -> [Float] {
        var sumSquares: Float = 0
        for x in v { sumSquares += x * x }
        let norm = sqrt(sumSquares)
        guard norm > 0 else { return v }
        let inv = 1 / norm
        return v.map { $0 * inv }
    }
    
    /// Dot-product similarity. Use with unnormalized vectors or unit vectors depending on your retrieval setup.
    public static func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return .nan }
        var dot: Float = 0
        for i in 0..<a.count { dot += a[i] * b[i] }
        return dot
    }
    
    /// Negative Euclidean distance as a similarity (higher is more similar).
    public static func negativeEuclidean(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return .nan }
        var sum: Float = 0
        for i in 0..<a.count { let d = a[i] - b[i]; sum += d * d }
        return -sqrt(sum)
    }
}
