import Foundation

extension GameEngine {
    public func distance(from sourceID: Int, to targetID: Int) -> Int {
        let living = players.filter(\.isAlive).map(\.id)
        guard let source = living.firstIndex(of: sourceID), let target = living.firstIndex(of: targetID) else { return .max }
        let gap = abs(source - target)
        let base = min(gap, living.count - gap)
        let sourceMount = players[sourceID].equipment[.offensiveHorse] == nil ? 0 : 1
        let targetMount = players[targetID].equipment[.defensiveHorse] == nil ? 0 : 1
        let horseSkill = players[sourceID].general == .maChao ? 1 : 0
        return max(1, base - sourceMount - horseSkill + targetMount)
    }

    public func isLegalTarget(_ targetID: Int, from sourceID: Int) -> Bool {
        guard players.indices.contains(sourceID), players.indices.contains(targetID), players[sourceID].isAlive,
              players[targetID].isAlive, targetID != sourceID else { return false }
        if players[targetID].general == .zhugeLiang, players[targetID].hand.isEmpty { return false }
        let range = players[sourceID].equipment[.weapon].map { weaponRange($0.kind) } ?? 1
        return distance(from: sourceID, to: targetID) <= range
    }

    public func canTarget(_ targetID: Int, with kind: CardKind, from sourceID: Int) -> Bool {
        guard players.indices.contains(sourceID), players.indices.contains(targetID), players[sourceID].isAlive,
              players[targetID].isAlive, targetID != sourceID else { return false }
        if kind == .duel, players[targetID].general == .zhugeLiang, players[targetID].hand.isEmpty { return false }
        return switch kind {
        case .slash, .dodge: isLegalTarget(targetID, from: sourceID)
        case .snatch: distance(from: sourceID, to: targetID) == 1
        case .dismantle, .duel: true
        case .indulgence: !players[targetID].delayedTricks.contains { $0.kind == .indulgence }
        case .collateral: players[targetID].equipment[.weapon] != nil
        default: false
        }
    }

}
