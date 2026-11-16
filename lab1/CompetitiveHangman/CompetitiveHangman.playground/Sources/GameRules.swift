import Foundation

public protocol GameRule {
    var ruleName: String { get }
    func outcome(for puzzle: WordGuessing, drawing: HangmanDrawing) -> RoundResult?
}

public struct WordSolvedRule: GameRule {
    public let ruleName = "All letters revealed"

    public init() {}

    public func outcome(for puzzle: WordGuessing, drawing: HangmanDrawing) -> RoundResult? {
        _ = drawing
        return puzzle.isSolved ? .solved : nil
    }
}

public struct MaximumMistakesRule: GameRule {
    public let ruleName = "Maximum mistakes reached"

    public init() {}

    public func outcome(for puzzle: WordGuessing, drawing: HangmanDrawing) -> RoundResult? {
        _ = puzzle
        return drawing.isAtLimit ? .lost : nil
    }
}
