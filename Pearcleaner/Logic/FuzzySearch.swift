import Foundation

/// FuzzySearchCharacters is used to normalise strings
struct FuzzySearchCharacter {
    let content: String
    // normalised content is referring to a string that is case- and accent-insensitive
    let normalisedContent: String
}

/// FuzzySearchString is just made up by multiple characters, similar to a string, but also with normalised characters
struct FuzzySearchString {
    var characters: [FuzzySearchCharacter]
}

/// FuzzySearchMatchResult represents an object that has undergone a fuzzy search using the fuzzyMatch function.
struct FuzzySearchMatchResult {
    let weight: Int
    let matchedParts: [NSRange]
}

extension String {
    /// Normalises the characters of the string by converting them to ASCII representation.
    /// Each character is transformed into its ASCII equivalent, and the resulting array
    /// of FuzzySearchCharacter objects contains both the original and normalised content.
    ///
    /// - Returns: An array of FuzzySearchCharacter objects representing the original and
    /// normalised content of each character in the string.
    func normalise() -> [FuzzySearchCharacter] {
        return self.lowercased().map { char in
            guard let data = String(char).data(using: .ascii, allowLossyConversion: true),
                  let normalisedCharacter = String(data: data, encoding: .ascii) else {
                return FuzzySearchCharacter(content: String(char), normalisedContent: String(char))
            }

            return FuzzySearchCharacter(content: String(char), normalisedContent: normalisedCharacter)
        }
    }
    /**
      Checks if the string has a prefix matching a fuzzy search character starting at a specified index.

      - Parameters:
        - prefix: A `FuzzySearchCharacter` object containing both content and normalized content for the prefix to search.
        - index: The index at which to start searching for the prefix within the string.

      - Returns: An optional integer representing the length of the matched prefix if found; otherwise, `nil`.
    */
    func hasPrefix(prefix: FuzzySearchCharacter, startingAt index: Int) -> Int? {
        guard let stringIndex = self.index(self.startIndex, offsetBy: index, limitedBy: self.endIndex) else {
            return nil
        }

        let searchString = self.suffix(from: stringIndex)

        for prefix in [prefix.content, prefix.normalisedContent] where searchString.hasPrefix(prefix) {
            return prefix.count
        }

        return nil
    }
}

/// A protocol defining the requirements for an object that can be searched using fuzzy matching.
protocol FuzzySearchable {
    var searchableString: String { get }

    /// Performs a fuzzy search on the conforming object's searchable string.
    ///
    /// - Parameters:
    ///   - query: The query string to match against the searchable content.
    ///   - characters: The set of characters used for fuzzy matching.
    ///
    /// - Returns: A FuzzySearchMatchResult indicating the result of the fuzzy search.
    func fuzzyMatch(query: String, characters: FuzzySearchString) -> FuzzySearchMatchResult
}

extension FuzzySearchable {
    func fuzzyMatch(query: String, characters: FuzzySearchString) -> FuzzySearchMatchResult {
        let compareString = characters.characters

        let searchString = query.lowercased()

        var totalScore = 0
        var matchedParts = [NSRange]()

        var patternIndex = 0
        var currentScore = 0
        var currentMatchedPart = NSRange(location: 0, length: 0)

        for (index, character) in compareString.enumerated() {
            if let prefixLength = searchString.hasPrefix(prefix: character, startingAt: patternIndex) {
                patternIndex += prefixLength
                currentScore += 1
                currentMatchedPart.length += 1
            } else {
                currentScore = 0
                if currentMatchedPart.length != 0 {
                    matchedParts.append(currentMatchedPart)
                }
                currentMatchedPart = NSRange(location: index + 1, length: 0)
            }

            totalScore += currentScore
        }

        if currentMatchedPart.length != 0 {
            matchedParts.append(currentMatchedPart)
        }

        if searchString.count == matchedParts.reduce(0, { partialResult, range in
            range.length + partialResult
        }) {
            return FuzzySearchMatchResult(weight: totalScore, matchedParts: matchedParts)
        } else {
            return FuzzySearchMatchResult(weight: 0, matchedParts: [])
        }
    }

    /// Normalises the searchable string of the conforming object by converting its characters to ASCII representation.
    /// The resulting FuzzySearchString contains both the original and normalised content of each character.
    ///
    /// - Returns: A FuzzySearchString
    func normaliseString() -> FuzzySearchString {
        return FuzzySearchString(characters: searchableString.normalise())
    }

    /// Performs a fuzzy search on the normalised content of the conforming object's searchable string.
    ///
    /// - Parameter query: The query string to match against the normalised searchable content.
    ///
    /// - Returns: A FuzzySearchMatchResult indicating the result of the fuzzy search.
    func fuzzyMatch(query: String) -> FuzzySearchMatchResult {
        let characters = normaliseString()

        return fuzzyMatch(query: query, characters: characters)
    }
}

extension Collection where Iterator.Element: FuzzySearchable {
    /// Asynchronously performs a fuzzy search on a collection of elements conforming to FuzzySearchable.
    ///
    /// - Parameter query: The query string to match against the elements.
    ///
    /// - Returns: An array of tuples containing FuzzySearchMatchResult and the corresponding element.
    ///
    /// - Note: Because this is an extension on Collection and not only array,
    /// you can also use this on sets.
    func fuzzySearch(query: String) -> [(result: FuzzySearchMatchResult, item: Iterator.Element)] {
        return map {
            (result: $0.fuzzyMatch(query: query), item: $0)
        }.filter {
            $0.result.weight > 0
        }.sorted {
            $0.result.weight > $1.result.weight
        }
    }
}