//
//  TokenSplitterTests.swift
//  SimilaritySearchKit
//
//  Created by Federico G. Ramos on 31.08.25.
//

import Testing
@testable import SimilaritySearchKit

@Suite(.serialized)
class TokenSplitterTests {
    // MARK: - Setup
    private let tokenizer = BertTokenizer()
    private lazy var splitter = TokenSplitter(withTokenizer: tokenizer)
    
    // MARK: - Basic splitting behavior
    @Test
    func testNoOverlapRespectsTokenBudget() {
        // Each single letter should be a standalone token for WordPiece
        let text = "a b c d e f g h i j k l m n o p q r s t u v w x y z"
        let chunkSize = 8
        let (chunks, tokensPerChunkOpt) = splitter.split(text: text, chunkSize: chunkSize, overlapSize: 0)
        #expect(!chunks.isEmpty)
        if let tokensPerChunk = tokensPerChunkOpt {
            for tokens in tokensPerChunk {
                #expect(tokens.count <= chunkSize)
            }
        }
    }
    
    // MARK: - Overlap behavior
    @Test
    func testTokenOverlapContinuity() {
        let text = "a b c d e f g h i j k l m n o p q r s t u v w x y z"
        let chunkSize = 8
        let overlap = 2
        let (chunks, tokensPerChunkOpt) = splitter.split(text: text, chunkSize: chunkSize, overlapSize: overlap)
        #expect(chunks.count > 1)
        guard let tokensPerChunk = tokensPerChunkOpt else {
            Issue.record("Missing tokens array from splitter")
            return
        }
        for i in 0..<(tokensPerChunk.count - 1) {
            let a = tokensPerChunk[i]
            let b = tokensPerChunk[i + 1]
            // Suffix of a must equal prefix of b with length == overlap
            let k = min(overlap, min(a.count, b.count))
            #expect(k > 0)
            let suffixA = Array(a.suffix(k))
            let prefixB = Array(b.prefix(k))
            #expect(suffixA == prefixB)
        }
    }
    
    // MARK: - Punctuation cut is not too early
    @Test
    func testPunctuationCutLateEnough() {
        // A longer sentence with a period near the end. We expect the first chunk to cut at '.'
        // but not create a tiny chunk. The thresholds in the splitter require ~40% of window size
        // and at least max(16, chunkSize/3) tokens.
        let text = "Swift tokenizers often split subwords depending on vocabulary, but this sentence should contain enough distinct tokens to pass the floor and cut near the end."
        let chunkSize = 48
        let (chunks, tokensPerChunkOpt) = splitter.split(text: text, chunkSize: chunkSize, overlapSize: 0)
        #expect(!chunks.isEmpty)
        guard let first = chunks.first else { return }
        // It should end with a period, or if not, still be reasonably large
        if first.hasSuffix(".") {
            if let tokensPerChunk = tokensPerChunkOpt {
                let t0 = tokensPerChunk.first ?? []
                #expect(t0.count >= max(16, chunkSize/3))
                #expect(t0.count <= chunkSize)
            }
        } else {
            // If no '.', then we didn't cut early. Ensure it's at least half of the budget.
            if let tokensPerChunk = tokensPerChunkOpt {
                let t0 = tokensPerChunk.first ?? []
                #expect(t0.count >= chunkSize / 2)
            }
        }
    }
    
    // MARK: - Empty and whitespace input
    @Test
    func testEmptyWhitespace() {
        let (chunks1, _) = splitter.split(text: "", chunkSize: 10, overlapSize: 0)
        let (chunks2, _) = splitter.split(text: "   \n\n  ", chunkSize: 10, overlapSize: 0)
        #expect(chunks1.isEmpty)
        #expect(chunks2.isEmpty)
    }

}
