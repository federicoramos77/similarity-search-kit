//
//  RecursiveCharacterSplitter.swift
//
//  Created by Leszek Mielnikow on 03/07/2023.
//

import Foundation

/// A text splitter that recursively attempts to split text using progressively smaller separators
/// (`"\n\n"`, `"\n"`, `"."`, `" "`).
/// - Ensures each chunk respects the specified character budget (`chunkSize`).
/// - Supports overlap between chunks by reusing the trailing units of the previous chunk.
/// - Falls back to smaller separators when larger ones produce oversized chunks.
public class RecursiveCharacterSplitter: TextSplitterProtocol {
    let characterSplitter: CharacterSplitter
    
    public init() {
        characterSplitter = CharacterSplitter()
    }
    
    /// Splits the given text into chunks using recursive separators.
    /// - Parameters:
    ///   - text: The input text to split.
    ///   - chunkSize: The maximum number of characters per chunk (default: 100).
    ///   - overlapSize: The number of units from the previous chunk to overlap into the next (default: 0).
    /// - Returns: A tuple containing:
    ///   - An array of chunk strings.
    ///   - An optional array of token arrays for each chunk, if available.
    ///   - Note: For this character-based splitter, the tokens array is always nil.
    public func split(text: String, chunkSize: Int = 100, overlapSize: Int = 0) -> ([String], [[String]]?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return ([], []) }
        let separators = ["\n\n", "\n", ".", " "]
        for separator in separators {
            if let (chunks, _) = trySplitWithSeparator(text: trimmed, separator: separator, chunkSize: chunkSize, overlapSize: overlapSize) {
                return (chunks, nil)
            }
        }
        return ([], nil)
    }
    
    /// Attempts to split the text using a single specified separator.
    /// - Parameters:
    ///   - text: The input text.
    ///   - separator: The separator string used to split the text.
    ///   - chunkSize: The maximum number of characters allowed per chunk.
    ///   - overlapSize: The number of units from the previous chunk to overlap into the next.
    /// - Returns: A tuple of (chunks, []) if the separator produces valid chunks, or nil if any unit exceeds the chunk size and the separator is not viable.
    private func trySplitWithSeparator(text: String, separator: String, chunkSize: Int, overlapSize: Int) -> ([String], [[String]])? {
        // Split into units by separator and drop empties
        let units = text.components(separatedBy: separator).filter { !$0.isEmpty }
        guard !units.isEmpty else { return ([], []) }
        // If any single unit exceeds budget, this separator is not viable
        for unit in units where unit.count > chunkSize { return nil }
        
        var chunks: [String] = []
        
        var currentUnits: [String] = []
        var currentLen = 0
        let sepLen = separator.count
        var i = 0
        while i < units.count {
            let u = units[i]
            let addLen = u.count + (currentUnits.isEmpty ? 0 : sepLen)
            if currentLen + addLen <= chunkSize {
                currentUnits.append(u)
                currentLen += addLen
                i += 1
            } else {
                if !currentUnits.isEmpty {
                    // finalize current chunk
                    var chunkText = currentUnits.joined(separator: separator)
                    if separator == "." && !chunkText.hasSuffix(".") {
                        if chunkText.count + 1 <= chunkSize { chunkText += "." }
                    }
                    chunks.append(chunkText)
                    
                    // prepare overlap by units
                    var overlapUnits = Array(currentUnits.suffix(max(0, min(overlapSize, currentUnits.count))))
                    
                    // trim from front until overlap + next unit fits budget
                    func joinedLen(_ arr: [String]) -> Int {
                        arr.isEmpty ? 0 : arr.joined(separator: separator).count
                    }
                    
                    var overlapLen = joinedLen(overlapUnits)
                    let nextUnitExtra = (overlapLen == 0 ? 0 : sepLen) + u.count
                    while !overlapUnits.isEmpty && overlapLen + nextUnitExtra > chunkSize {
                        overlapUnits.removeFirst()
                        overlapLen = joinedLen(overlapUnits)
                    }
                    currentUnits = overlapUnits
                    currentLen = overlapLen
                    // retry same unit on next loop
                    continue
                } else {
                    // This unit alone does not fit even in an empty chunk -> not viable
                    return nil
                }
            }
        }
        if !currentUnits.isEmpty {
            var finalChunk = currentUnits.joined(separator: separator)
            if separator == "." && !finalChunk.hasSuffix(".") {
                if finalChunk.count + 1 <= chunkSize { finalChunk += "." }
            }
            chunks.append(finalChunk)
        }
        return (chunks, [])
    }
}
