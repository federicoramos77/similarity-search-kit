//
//  TokenSplitter.swift
//
//
//  Created by Zach Nagengast on 4/25/23.
//

import Foundation

/// Encodes input text and return chunks based on chunk size
/// Ideal for speed if you don't mind losing some information to unknown tokens
/// during the encode/decode process
public class TokenSplitter: TextSplitterProtocol {
    let tokenizer: any TokenizerProtocol
    
    public required init(withTokenizer: any TokenizerProtocol) {
        self.tokenizer = withTokenizer
    }
    
    public func split(text: String, chunkSize: Int = 510, overlapSize: Int = 0) -> ([String], [[String]]?) {
        // Return an empty list if the text is empty or whitespace
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ([], [])
        }
        
        // Hard cap to 510 as this splitter is intended for BERT-like models
        let chunkSize = min(chunkSize, 510)
        let overlapTokens = max(0, overlapSize)
        
        // Tokenize once
        let tokens = tokenizer.tokenize(text: text)
        var remainingTokens = tokens[...]
        
        var chunks: [String] = []
        var chunkTokens: [[String]] = []
        
        // Always make forward progress to avoid infinite loops
        func advance(_ count: Int) {
            let c = max(1, count)
            let dropCount = min(c, remainingTokens.count)
            remainingTokens.removeFirst(dropCount)
        }
        
        while !remainingTokens.isEmpty {
            // Window of up to chunkSize tokens
            let windowCount = min(chunkSize, remainingTokens.count)
            let window = Array(remainingTokens.prefix(windowCount))
            
            // Decode the window to try a punctuation-friendly cut
            let windowText = tokenizer.detokenize(tokens: window)
            
            // Prefer sentence-ending punctuation, ignore newlines which can appear at index 0
            let punctuationMarks: [Character] = [".", "?", "!"]
            let lastPuncIndex = punctuationMarks
                .compactMap { windowText.lastIndex(of: $0)?.utf16Offset(in: windowText) }
                .max() ?? -1
            
            var chunkText = windowText
            var usedTokenCount = window.count
            
            if lastPuncIndex != -1 {
                // Candidate cut at punctuation
                let end = min(windowText.count, lastPuncIndex + 1)
                let endIdx = windowText.index(windowText.startIndex, offsetBy: end)
                let candidate = String(windowText[..<endIdx])
                
                // Require the punctuation cut to be late enough and large enough
                let approx = tokenizer.tokenize(text: candidate).count
                let minTokensForCut = max(16, chunkSize / 3)                 // token floor
                let minCharsForCut  = max(8, Int(Double(windowText.count) * 0.40)) // char floor ~40%
                
                if approx >= minTokensForCut && end >= minCharsForCut {
                    chunkText = candidate
                    usedTokenCount = min(max(approx, 1), window.count)
                } else {
                    // Too early or too small: keep full window
                    chunkText = windowText
                    usedTokenCount = window.count
                }
            }
            
            // Normalize whitespace
            chunkText = chunkText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if chunkText.isEmpty {
                // Fallback: at least consume one token to avoid stalling
                advance(1)
                continue
            }
            
            // Append outputs
            chunks.append(chunkText)
            chunkTokens.append(Array(window.prefix(usedTokenCount)))
            
            // Advance with overlap: keep the tail of the used tokens
            let advanceCount = usedTokenCount - min(overlapTokens, usedTokenCount - 1)
            advance(advanceCount)
            // Stop if only overlap-sized tokens remain; avoids tiny trailing duplicates
            if overlapTokens > 0 && remainingTokens.count <= overlapTokens {
                break
            }
            // Realign next window to a fresh word boundary. Avoid starting at subword tokens like "##s".
            while let first = remainingTokens.first, first.hasPrefix("##") {
                remainingTokens.removeFirst()
            }
        }
        
        return (chunks, chunkTokens)
    }
}
