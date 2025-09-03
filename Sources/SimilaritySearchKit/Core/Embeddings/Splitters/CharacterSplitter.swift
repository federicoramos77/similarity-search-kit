//
//  CharacterSplitter.swift
//
//
//  Created by Zach Nagengast on 4/25/23.
//

import Foundation

/// A simple splitter that divides text into chunks based on a given separator.
/// - The `separator` defines what constitutes a *unit*:
///   - `""` → each character is a unit,
///   - `" "` → each word is a unit,
///   - any other string → units are defined by that separator.
/// - `chunkSize` limits the number of units in each chunk (not character count).
/// - `overlapSize` allows trailing units from one chunk to carry over into the next.
/// - The separator itself does not count toward the chunk size budget.
public class CharacterSplitter: TextSplitterProtocol {
    let separator: String
    
    public init(withSeparator separator: String? = nil) {
        // Default separator is character breaks
        self.separator = separator ?? ""
    }
    
    /// Splits the input text into chunks based on the separator, appending components until the chunk size is reached.
    ///
    /// The `chunkSize` parameter refers to the maximum number of characters including separators per chunk.
    /// The separator itself counts toward the chunk size budget.
    ///
    /// - Parameters:
    ///   - text: The input string to split.
    ///   - chunkSize: The maximum number of characters including separators per chunk (default: 100).
    ///   - overlapSize: The number of units to overlap between chunks (default: 0).
    /// - Returns: A tuple containing the array of split chunks and an optional array of metadata.
    public func split(text: String, chunkSize: Int = 100, overlapSize: Int = 0) -> ([String], [[String]]?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return ([], nil)
        }
        
        let components = trimmed.components(separatedBy: separator)
        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentCount = 0
        
        for component in components {
            if currentCount < chunkSize {
                currentChunk.append(component)
                currentCount += 1
            } else {
                chunks.append(currentChunk.joined(separator: separator).trimmingCharacters(in: .whitespaces))
                let overlapStart = max(0, currentChunk.count - overlapSize)
                currentChunk = Array(currentChunk[overlapStart...])
                currentCount = currentChunk.count
                currentChunk.append(component)
                currentCount += 1
            }
        }
        
        // Add the last chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: separator).trimmingCharacters(in: .whitespaces))
        }
        
        return (chunks, nil)
    }
}
