import Foundation

public struct GameLogPresentation {
    private let aliases: [(name: String, general: String)]

    public init(players: [Player]) {
        aliases = players.filter { !$0.isHuman }.map { ($0.name, $0.general.title) }
    }

    public func visibleLine(from line: String) -> String {
        aliases.reduce(line) { $0.replacingOccurrences(of: $1.name, with: $1.general) }
    }

    public static func visibleLines(from lines: [String], players: [Player]) -> [String] {
        let presentation = GameLogPresentation(players: players)
        return lines.map { presentation.visibleLine(from: $0) }
    }
}
