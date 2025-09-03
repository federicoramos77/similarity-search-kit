//
//  CharacterSplitter.swift
//  SimilaritySearchKit
//
//  Created by Federico G. Ramos on 31.08.25.
//

import Testing
@testable import SimilaritySearchKit

@Suite(.serialized)
class CharacterSplitterTests {
    // MARK: - Setup
    private let splitter = CharacterSplitter(withSeparator: " ")
    
    // MARK: - Basic splitting behavior
    @Test
    func testNoOverlapRespectsBudget() {
        let text = "a b c d e f g h i j k l m n o p q r s t u v w x y z"
        let chunkSize = 5
        let (chunks, _) = splitter.split(text: text, chunkSize: chunkSize, overlapSize: 0)
        for chunk in chunks {
            let units = chunk.split(separator: " ").filter{ !$0.isEmpty }   // " " => words
            #expect(units.count <= chunkSize)
        }
    }
    
    // MARK: - Overlap behavior
    @Test
    func testCharacterOverlapContinuity() {
        let text = "a b c d e f g h i j k l m n o p q r s t u v w x y z"
        let chunkSize = 6
        let overlap = 2
        let (chunks, _) = splitter.split(text: text, chunkSize: chunkSize, overlapSize: overlap)
        #expect(chunks.count > 1)
        for i in 0..<(chunks.count - 1) {
            let a = chunks[i].split(separator: " ").map(String.init)
            let b = chunks[i+1].split(separator: " ").map(String.init)
            let aSuffix = Array(a.suffix(overlap))
            let bPrefix = Array(b.prefix(overlap))
            #expect(aSuffix == bPrefix)
        }
    }
    
    // MARK: - Empty and whitespace input
    @Test
    func testEmptyWhitespace() {
        let (chunks1, _) = splitter.split(text: "", chunkSize: 4, overlapSize: 0)
        let (chunks2, _) = splitter.split(text: "   ", chunkSize: 4, overlapSize: 0)
        #expect(chunks1.isEmpty)
        #expect(chunks2.isEmpty)
    }
}
