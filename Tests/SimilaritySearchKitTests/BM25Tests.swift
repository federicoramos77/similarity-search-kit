//
//  BM25Tests.swift
//  SimilaritySearchKit
//
//  Created by Assistant on 30.09.25.
//

import Foundation
import Testing
@testable import SimilaritySearchKit

@Suite(.serialized)
class BM25Tests {
    // MARK: - Fixtures
    private let corpus: [String] = [
        "apple banana",
        "banana fruit",
        "car truck",
        "apple apple pie"
    ]

    // MARK: - Basic behavior
    @Test
    func testRank_basicOrdering() {
        let query = "apple banana"
        let results = BM25.rank(query: query, documents: corpus)

        // Expect top-2 indices to include the doc with both terms (0) and the doc with multiple apples (3)
        let top2 = Array(results.prefix(2))
        let topIndices = top2.map { $0.1 }
        #expect(topIndices.contains(0))
        #expect(topIndices.contains(3))

        // Scores are descending
        for i in 1..<results.count {
            #expect(results[i-1].0 >= results[i].0)
        }

        // If scores tie, lower index comes first
        for i in 1..<results.count {
            if abs(results[i-1].0 - results[i].0) < 1e-6 {
                #expect(results[i-1].1 < results[i].1)
            }
        }
    }

    // MARK: - Deterministic tie-breaking
    @Test
    func testRank_tieBreaksByLowerIndex() {
        // Two docs with same single term once and same length
        let docs = [
            "single",
            "single"
        ]
        let results = BM25.rank(query: "single", documents: docs)

        // Scores should be identical
        #expect(abs(results[0].0 - results[1].0) < 1e-6)
        // Lower index first
        #expect(results[0].1 == 0)
        #expect(results[1].1 == 1)
    }

    // MARK: - Edge cases
    @Test
    func testRank_emptyInputs() {
        // Empty corpus returns empty results
        let emptyCorpusResults = BM25.rank(query: "apple", documents: [])
        #expect(emptyCorpusResults.isEmpty)

        // Query tokenizes to empty (punctuation only) returns empty results
        let emptyQueryResults = BM25.rank(query: "!!!", documents: corpus)
        #expect(emptyQueryResults.isEmpty)
    }

    // MARK: - Parameter sensitivity
    @Test
    func testRank_parametersAffectScoring() {
        let query = "apple banana"

        let resultsDefault = BM25.rank(query: query, documents: corpus, k1: 1.5, b: 0.75)
        let resultsModified = BM25.rank(query: query, documents: corpus, k1: 2.0, b: 0.9)

        // At least one document's score differs between the two runs
        var differs = false
        for i in 0..<corpus.count {
            if abs(resultsDefault[i].0 - resultsModified[i].0) > 1e-5 {
                differs = true
                break
            }
        }
        #expect(differs)
    }

    // MARK: - Sorting and coverage
    @Test
    func testRank_allDocsReturnedAndSorted() {
        let query = "banana"
        let results = BM25.rank(query: query, documents: corpus)

        // Rank returns a score for every document
        #expect(results.count == corpus.count)

        // Results sorted descending by score and ascending by index for ties
        for i in 1..<results.count {
            let prev = results[i-1]
            let curr = results[i]
            #expect(prev.0 >= curr.0)
            if abs(prev.0 - curr.0) < 1e-6 {
                #expect(prev.1 < curr.1)
            }
        }
    }
}
