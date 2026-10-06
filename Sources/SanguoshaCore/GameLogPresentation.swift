import Foundation

public enum GameLogPresentation {
    public static func visibleLines(from lines: [String], players: [Player]) -> [String] {
        let aliases = players.filter { !$0.isHuman }.map { ($0.name, $0.general.title) }
        return lines.map { line in
            aliases.reduce(line) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
        }
    }
}
