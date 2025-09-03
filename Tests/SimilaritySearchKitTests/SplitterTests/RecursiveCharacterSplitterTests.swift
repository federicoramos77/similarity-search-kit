//
//  RecursiveCharacterSplitterTests.swift
//  SimilaritySearchKit
//
//  Created by Federico G. Ramos on 31.08.25.
//

import Testing
@testable import SimilaritySearchKit

@Suite(.serialized)
class RecursiveCharacterSplitterTests {
    // MARK: - Setup
    private let splitter = RecursiveCharacterSplitter()
    
    // MARK: - Basic splitting behavior
    @Test
    func testNoOverlapRespectsBudget() {
        let text = "a b c d e f g h i j k l m n o p q r s t u v w x y z"
        let chunkSize = 12
        let (chunks, _) = splitter.split(text: text, chunkSize: chunkSize, overlapSize: 0)
        #expect(!chunks.isEmpty)
        for chunk in chunks {
            #expect(chunk.count <= chunkSize)
        }
    }
    
    // MARK: - Overlap behavior
    @Test
    func testCharacterOverlapContinuity() {
        let text = "a b c d e f g h i j k l m n o p q r s t u v w x y z"
        let chunkSize = 12
        let overlap = 4
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
    
    // MARK: - Structure preservation
    @Test
    func testRespectsSentenceBoundaries() {
        let text = "This is sentence one. This is sentence two. This is sentence three."
        let chunkSize = 24
        let (chunks, _) = splitter.split(text: text, chunkSize: chunkSize, overlapSize: 0)
        #expect(!chunks.isEmpty)
        #expect(chunks.count == 3)
        // Expect that chunks end with '.' when possible
        for chunk in chunks.dropLast() {
            #expect(chunk.count <= chunkSize)
            print(chunk)
            #expect(chunk.hasSuffix("."))
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
