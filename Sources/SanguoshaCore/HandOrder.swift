import Foundation

public enum HandOrder {
    public static func reconciling(_ orderedIDs: [Int], with availableIDs: [Int]) -> [Int] {
        let available = Set(availableIDs)
        let retained = orderedIDs.filter { available.contains($0) }
        let retainedSet = Set(retained)
        return retained + availableIDs.filter { !retainedSet.contains($0) }
    }

    public static func moving(_ cardID: Int, before targetID: Int, in orderedIDs: [Int]) -> [Int] {
        guard cardID != targetID, orderedIDs.contains(cardID), orderedIDs.contains(targetID) else { return orderedIDs }
        var result = orderedIDs.filter { $0 != cardID }
        guard let targetIndex = result.firstIndex(of: targetID) else { return orderedIDs }
        result.insert(cardID, at: targetIndex)
        return result
    }
}
