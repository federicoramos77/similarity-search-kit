//
//  BM25.swift
//  SimilaritySearchKit
//
//  Created by Federico G. Ramos on 30.09.25.
//

import Foundation

public struct BM25 {
    /// Tokenize the input text into lowercase alphanumeric tokens.
    private static func tokenize(_ text: String) -> [String] {
        return text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Compute BM25 ranking scores for the documents given a query.
    /// - Parameters:
    ///   - query: Query string.
    ///   - documents: Array of document strings.
    ///   - k1: BM25 k1 parameter (default 1.5).
    ///   - b: BM25 b parameter (default 0.75).
    /// - Returns: Array of tuples (score, documentIndex) sorted descending by score.
    public static func rank(query: String, documents: [String], k1: Float = 1.5, b: Float = 0.75) -> [(Float, Int)] {
        guard !documents.isEmpty else { return [] }

        let queryTerms = Array(Set(tokenize(query)))
        if queryTerms.isEmpty { return [] }

        let N = Float(documents.count)

        // Tokenize documents and compute document lengths and term frequencies.
        var docTermFreqs: [[String: Int]] = []
        var docLengths: [Int] = []

        for doc in documents {
            let tokens = tokenize(doc)
            docLengths.append(tokens.count)
            var freqs: [String: Int] = [:]
            for t in tokens {
                freqs[t, default: 0] += 1
            }
            docTermFreqs.append(freqs)
        }

        let avgdl = docLengths.reduce(0, +) == 0 ? 0 : Float(docLengths.reduce(0, +)) / N

        // Compute document frequencies for query terms.
        var docFreqs: [String: Int] = [:]
        for t in queryTerms {
            var df = 0
            for freqs in docTermFreqs {
                if freqs[t] != nil {
                    df += 1
                }
            }
            docFreqs[t] = df
        }

        // Calculate scores for each document.
        var results: [(Float, Int)] = []

        for (index, freqs) in docTermFreqs.enumerated() {
            let dl = Float(docLengths[index])
            var score: Float = 0

            for t in queryTerms {
                guard let df = docFreqs[t], df > 0 else { continue }

                // IDF calculation
                let idf = logf((N - Float(df) + 0.5) / (Float(df) + 0.5) + 1)

                let tf = Float(freqs[t] ?? 0)
                let denom = tf + k1 * (1 - b + b * dl / avgdl)
                let termScore = idf * (tf * (k1 + 1)) / denom

                score += termScore
            }

            results.append((score, index))
        }

        // Sort by score descending, break ties by lower index.
        results.sort {
            if $0.0 == $1.0 {
                return $0.1 < $1.1
            }
            return $0.0 > $1.0
        }

        return results
    }
}
