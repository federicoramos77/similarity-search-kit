//
//  RecursiveTokenSplitter.swift
//
//
//  Created by Zach Nagengast on 4/26/23.
//

import Foundation

/// Uses a progressively smaller set of text seperators to try to fit the goal chunk size in tokens without going over.
/// Recommended if you want to preserve punctuation and unknown or out-of-vocabulary tokens from the original input,
/// since it never reconstructs chunk text by detokenizing, it uses the original substrings.
public class RecursiveTokenSplitter: TextSplitterProtocol {
    /// The tokenizer used to convert text into tokens and back for splitting operations.
    let tokenizer: any TokenizerProtocol
    
    /// Creates a new splitter with the provided tokenizer.
    /// - Parameter withTokenizer: An instance conforming to `TokenizerProtocol` used to tokenize input text.
    public required init(withTokenizer: any TokenizerProtocol) {
        self.tokenizer = withTokenizer
    }
    
    /// Splits text into sequential chunks of tokens, ensuring each chunk respects the token budget.
    ///
    /// The method progressively tries different separators (`"\n\n"`, `"\n"`, `". "`, space, character-level)
    /// to keep semantic boundaries where possible. Overlap tokens from the end of one chunk are carried into
    /// the beginning of the next chunk.
    ///
    /// - Parameters:
    ///   - text: The input string to split.
    ///   - chunkSize: Maximum number of tokens per chunk (default 510).
    ///   - overlapSize: Number of tokens from the end of the previous chunk to repeat at the start of the next (default 0).
    /// - Returns: A tuple `(chunks, chunkTokens)` where `chunks` are reconstructed text segments and
    ///            `chunkTokens` are the corresponding token arrays, or `nil` if no valid split is possible.
    public func split(text: String, chunkSize: Int = 510, overlapSize: Int = 0) -> ([String], [[String]]?) {
        guard !text.isEmpty else { return ([], nil) }
        
        let separators = ["\n\n", "\n", ". ", " ", ""]
        
        // Account for [CLS] and [SEP] tokens
        let targetChunkSize = min(chunkSize, 510)
        
        // Clamp overlap range: [0, targetChunkSize - 1]
        let requestedOverlap = max(0, min(abs(overlapSize), max(0, targetChunkSize - 1)))
        
        for separator in separators {
            let splits = text.components(separatedBy: separator).filter { !$0.isEmpty }
            
            // Precompute segments once per separator: text-with-sep + tokens
            let segments: [Segment] = splits.map { part in
                let segText = part + separator
                return Segment(text: segText, tokens: tokenizer.tokenize(text: segText))
            }
            
            // Precheck: every segment must fit alone within the budget
            guard segments.allSatisfy({ $0.tokenCount <= targetChunkSize }) else { continue }
            
            var chunks: [String] = []
            var chunkTokens: [[String]] = []
            
            // Accumulate current chunk as a list of precomputed segments
            var currentSegments: [Segment] = []
            var currentTokenCount = 0
            
            // Helper to flush currentSegments into output arrays
            func flush() {
                guard !currentSegments.isEmpty else { return }
                let chunkText = currentSegments.map { $0.text }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                let tokens = currentSegments.flatMap { $0.tokens }
                chunks.append(chunkText)
                chunkTokens.append(tokens)
            }
            
            for segment in segments {
                if currentTokenCount + segment.tokenCount <= targetChunkSize {
                    currentSegments.append(segment)
                    currentTokenCount += segment.tokenCount
                    continue
                }
                
                // Exceeds budget. Build overlap from the tail of currentSegments by token count
                let previousSegments = currentSegments
                flush()
                
                var overlapSegments: [Segment] = []
                var tokensNeeded = min(requestedOverlap, previousSegments.reduce(0) { $0 + $1.tokenCount })
                for s in previousSegments.reversed() where tokensNeeded > 0 {
                    overlapSegments.insert(s, at: 0)
                    tokensNeeded -= s.tokenCount
                }
                
                let overlapCount = overlapSegments.reduce(0) { $0 + $1.tokenCount }
                if overlapCount + segment.tokenCount <= targetChunkSize {
                    currentSegments = overlapSegments + [segment]
                    currentTokenCount = overlapCount + segment.tokenCount
                } else {
                    // Start fresh without overlap
                    currentSegments = [segment]
                    currentTokenCount = segment.tokenCount
                }
            }
            
            // Flush tail
            flush()
            
            return (chunks, chunkTokens)
        }
        
        return ([], nil)
    }
    
    // MARK: - Helpers
    
    /// Token-budget precheck for a given split strategy.
    ///
    /// Validates that **each** pre-split segment can fit within the token budget `maxChunkSize` on its own.
    /// This does **not** construct final windows or apply overlap; it only ensures that no single segment
    /// exceeds the per-chunk token limit for the current separator strategy.
    ///
    /// - Parameters:
    ///   - chunks: Text segments produced by a candidate separator (e.g., by `components(separatedBy:)`).
    ///   - maxChunkSize: Maximum allowed tokens **per segment** for this precheck. Overlap is handled later,
    ///                   so pass the appropriate budget from the caller.
    /// - Returns: Tuple `(isValid, splitTokens)` where `isValid` is `true` if all segments are within budget.
    ///            `splitTokens` contains the tokenized form of each segment in `chunks` (in order) when valid;
    ///            otherwise `[]` when invalid.
    ///
    /// - Complexity: O(N) tokenizations where N = `chunks.count`.
    ///
    /// - Note: This helper relies on the tokenizer’s behavior. If using a subword tokenizer (e.g., WordPiece),
    ///         the number of tokens per segment may exceed the number of whitespace-delimited words. Also be
    ///         mindful that splitting by the empty string `""` operates at scalar boundaries.
    private func isSplitValid(chunks: [String], maxChunkSize: Int) -> (Bool, [[String]]) {
        var splitTokens: [[String]] = []
        
        for chunk in chunks {
            let tokens = tokenizer.tokenize(text: chunk)
            if tokens.count > maxChunkSize {
                return (false, [])
            }
            splitTokens.append(tokens)
        }
        
        return (true, splitTokens)
    }
    
    /// Minimal unit that ties original text to its tokenization
    private struct Segment {
        let text: String
        let tokens: [String]
        var tokenCount: Int { tokens.count }
    }
}
