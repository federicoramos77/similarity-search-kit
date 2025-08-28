//
//  RecursiveTokenSplitterTests.swift
//  SimilaritySearchKit
//
//  Created by Federico G. Ramos on 25.08.25.
//

import Testing
@testable import SimilaritySearchKit

@Suite(.serialized)
class RecursiveTokenSplitterTests {
    // MARK: - Setup
    private let tokenizer = BertTokenizer()
    private lazy var splitter = RecursiveTokenSplitter(withTokenizer: tokenizer)
    
    // MARK: - Basic overlap behavior
    // NOTE: Each letter in the test strings simulates a token for easier reasoning about chunking.
    @Test
    func testNoOverlapChunk4() {
        let text = "a b c d e f g h i j k l m n o p q r s t"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 4, overlapSize: 0)
        #expect(
            chunks == ["a b c d", "e f g h", "i j k l", "m n o p", "q r s t"]
        )
        if let ids {
            for idArray in ids { #expect(idArray.count <= 4) }
        }
    }
    
    @Test
    func testOverlap2Chunk4() {
        let text = "a b c d e f g h i j k l m n o p q r s t"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 4, overlapSize: 2)
        #expect(
            chunks == [
                "a b c d",
                "c d e f",
                "e f g h",
                "g h i j",
                "i j k l",
                "k l m n",
                "m n o p",
                "o p q r",
                "q r s t"
            ]
        )
        if let ids {
            for idArray in ids { #expect(idArray.count <= 4) }
        }
    }
    
    @Test
    func testOverlap1Chunk5() {
        let text = "a b c d e f g h i j k l m n o p q r s t"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 5, overlapSize: 1)
        #expect(
            chunks == ["a b c d e", "e f g h i", "i j k l m", "m n o p q", "q r s t"]
        )
        if let ids {
            for idArray in ids { #expect(idArray.count <= 5) }
        }
    }
    
    @Test
    func testOverlapLargerThanChunkSizeBehavesLikeStride1() {
        let text = "a b c d e f g h i j k l m n o p q r s t"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 3, overlapSize: 10)
        #expect(
            chunks == [
                "a b c",
                "b c d",
                "c d e",
                "d e f",
                "e f g",
                "f g h",
                "g h i",
                "h i j",
                "i j k",
                "j k l",
                "k l m",
                "l m n",
                "m n o",
                "n o p",
                "o p q",
                "p q r",
                "q r s",
                "r s t"
            ]
        )
        if let ids {
            for idArray in ids { #expect(idArray.count <= 3) }
        }
    }
    
    // MARK: - Edge cases
    @Test
    func testEmptyInputReturnsEmpty() {
        let empty = ""
        let (chunksWithOverlap, idsOverlap) = splitter.split(text: empty, chunkSize: 4, overlapSize: 2)
        #expect(chunksWithOverlap.isEmpty)
        #expect(idsOverlap == nil || idsOverlap!.isEmpty)
        
        let (chunks, idsNoOverlap) = splitter.split(text: empty, chunkSize: 4, overlapSize: 0)
        #expect(chunks.isEmpty)
        #expect(idsNoOverlap == nil || idsNoOverlap!.isEmpty)
    }
    
    // MARK: - Detokenize integration
    @Test
    func testDetokenizeMatchesChunksNoPunctuation() {
        let text = "a b c d e f g h i j k l m n o p q r s t"
        let (chunks, tokenChunks) = splitter.split(text: text, chunkSize: 4, overlapSize: 2)
        #expect(tokenChunks != nil, "Expected tokenChunks to be non-nil")
        
        if let tokenChunks {
            #expect(chunks.count == tokenChunks.count)
            for i in 0..<chunks.count {
                let detok = tokenizer.detokenize(tokens: tokenChunks[i])
                #expect(detok == chunks[i])
            }
        }
    }
    
    @Test
    func testDetokenizeThenRetokenize_YieldsSameIds_NoOverlap() {
        let text = "SwiftUI is great for building UIs in 2025"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 8, overlapSize: 0)
        #expect(ids != nil)
        if let ids {
            #expect(chunks.count == ids.count)
            for i in 0..<ids.count {
                let detok = tokenizer.detokenize(tokens: ids[i])
                let roundTrip = tokenizer.tokenize(text: detok)
                #expect(roundTrip == ids[i])
            }
        }
    }
    
    @Test
    func testDetokenizeThenRetokenize_YieldsSameIds_WithOverlap() {
        let text = "Transformers are widely used for NLP tasks"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 6, overlapSize: 2)
        #expect(ids != nil)
        if let ids {
            #expect(chunks.count == ids.count)
            for i in 0..<ids.count {
                let detok = tokenizer.detokenize(tokens: ids[i])
                let roundTrip = tokenizer.tokenize(text: detok)
                #expect(roundTrip == ids[i])
            }
        }
    }
    
    @Test
    func testDetokenizeMatchesChunksSpacesOnly() {
        let text = "a b c d e f g h i"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 4, overlapSize: 2)
        #expect(ids != nil)
        if let ids {
            for i in 0..<chunks.count { #expect(tokenizer.detokenize(tokens: ids[i]) == chunks[i]) }
        }
    }
    
    // MARK: - Real string example with overlap
    @Test
    func testRealTextWithOverlap() {
        let text = "SwiftUI is great for building UIs. It uses a declarative syntax that is easy to read."
        let (chunks, ids) = splitter.split(text: text, chunkSize: 6, overlapSize: 2)
        #expect(
            chunks == ["SwiftUI is great for building", "for building UIs. It", "UIs. It uses a", "uses a declarative syntax", "declarative syntax that is", "that is easy to read."]
        )
        if let ids {
            for idArray in ids { #expect(idArray.count <= 6) }
        }
    }
    
    // MARK: - Real string example w/o overlap
    @Test
    func testRealTextWithoutOverlap() {
        let text = "SwiftUI is great for building UIs. It uses a declarative syntax that is easy to read."
        let (chunks, ids) = splitter.split(text: text, chunkSize: 6, overlapSize: 0)
        #expect(ids != nil)
        if let ids = ids {
            for idArray in ids { #expect(idArray.count <= 6) }
        }
        #expect(
            chunks == ["SwiftUI is great for building", "UIs. It uses a", "declarative syntax that is", "easy to read."]
        )
    }
    
    // MARK: - Short text
    @Test
    func testWholeTextFitsInOneChunk() {
        let text = "short text"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 50, overlapSize: 0)
        #expect(chunks.count == 1)
        #expect(chunks.first == "short text")
        #expect(ids != nil)
        if let ids {
            #expect(ids.count == 1)
        }
    }
    
    @Test
    func testSentenceSplitWithNewlines() {
        let text = "One.\n\nTwo.\n\nThree?"
        let (chunks, _) = splitter.split(text: text, chunkSize: 3, overlapSize: 0)
        #expect(chunks == ["One.", "Two.", "Three?"])
    }
    
    // MARK: - Emoji handling
    @Test
    func testEmojiWithoutOverlap() {
        let text = "a b 😀 c d 😎 e"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 3, overlapSize: 0)
        #expect(ids != nil)
        if let ids {
            for idArray in ids { #expect(idArray.count <= 3) }
        }
        #expect(
            chunks == ["a b 😀", "c d 😎", "e"]
        )
    }
    
    @Test
    func testEmojiWithOverlap1() {
        let text = "a b 😀 c d 😎 e"
        let (chunks, ids) = splitter.split(text: text, chunkSize: 3, overlapSize: 1)
        #expect(ids != nil)
        if let ids {
            for idArray in ids { #expect(idArray.count <= 3) }
        }
        #expect(
            chunks == ["a b 😀", "😀 c d", "d 😎 e"]
        )
    }
    
    // MARK: - Large input stress test
    @Test
    func testLargeInput1000TokensChunk500() {
        let tokens = Array(repeating: "the", count: 1000)
        let text = tokens.joined(separator: " ")
        
        let (chunks, ids) = splitter.split(text: text, chunkSize: 500, overlapSize: 0)
        
        // We expect 2 chunks: first 500 tokens, then 500 tokens
        #expect(chunks.count == 2)
        if let ids {
            #expect(ids.count == 2)
            #expect(ids[0].count <= 500)
            #expect(ids[1].count <= 500)
            #expect(ids[0].count + ids[1].count == 1000)
        }
        
        // Verify concatenated detokenized chunks reconstruct the original tokens
        let reconstructed = chunks.joined(separator: " ").split(separator: " ")
        #expect(reconstructed.count == 1000)
    }
    
    @Test
    func testLargeInput1000TokensChunk500WithOverlap100() {
        let tokens = Array(repeating: "the", count: 1000)
        let text = tokens.joined(separator: " ")
        
        let chunkSize = 500
        let overlap = 100
        
        let (chunks, idsOpt) = splitter.split(text: text, chunkSize: chunkSize, overlapSize: overlap)
        
        // Expect 3 chunks due to stride = 500 - 100 = 400
        #expect(chunks.count == 3)
        #expect(idsOpt != nil)
        
        if let ids = idsOpt {
            #expect(ids.count == 3)
            
            // Per-chunk sizes should not exceed chunkSize; last chunk is shorter (200)
            #expect(ids[0].count <= chunkSize)
            #expect(ids[1].count <= chunkSize)
            #expect(ids[2].count <= chunkSize)
            
            #expect(ids[0].count == 500)
            #expect(ids[1].count == 500)
            #expect(ids[2].count == 200)
            
            // Overlap correctness: last 100 of chunk0 == first 100 of chunk1
            let suffix0 = Array(ids[0].suffix(overlap))
            let prefix1 = Array(ids[1].prefix(overlap))
            #expect(suffix0 == prefix1)
            
            // Overlap correctness: last 100 of chunk1 == first 100 of chunk2
            let suffix1 = Array(ids[1].suffix(overlap))
            let prefix2 = Array(ids[2].prefix(min(overlap, ids[2].count)))
            #expect(Array(suffix1.prefix(prefix2.count)) == prefix2)
            
            // Coverage without gaps when removing overlaps
            let mergedCount = ids[0].count + (ids[1].count - overlap) + (ids[2].count - overlap)
            #expect(mergedCount == 1000)
        }
        
        // Sanity: ensure each chunk respects the budget
        if let ids = idsOpt {
            for idArray in ids { #expect(idArray.count <= chunkSize) }
        }
    }
    
}
