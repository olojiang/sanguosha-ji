public enum GameVoiceCue {
    public static func lines(from events: [String]) -> [String] {
        events.filter(isCardEvent)
    }

    public static func spokenLines(from events: [String], players: [Player]) -> [String] {
        let aliases = players.filter { !$0.isHuman }.map { ($0.name, $0.general.title) }
        return lines(from: events).map { event in
            var line = aliases.reduce(event) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
            if line.hasPrefix("你 ") { line.replaceSubrange(line.startIndex..<line.index(after: line.startIndex), with: "我") }
            return line.replacingOccurrences(of: " ", with: "")
        }
    }

    private static func isCardEvent(_ line: String) -> Bool {
        line.contains("使用杀") || line.contains("使用桃") || line.contains("使用酒")
            || line.contains("使用锦囊【") || line.contains("打出【")
            || line.contains("装备了") || line.contains("以杀应对决斗")
            || line.contains("从五谷丰登中获得")
            || line.contains("弃置了") && line.contains("【")
            || line.contains("获得【") || line.contains("造成") || line.contains("击杀了")
    }
}
