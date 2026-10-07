import Foundation

private struct PendingTrick {
    let card: Card
    let sourceID: Int
    let targetID: Int?
    var negationCount = 0
    var passedResponders: Set<Int> = []
}

public struct GameEngine {
    public private(set) var players: [Player]
    public private(set) var allCards: [Card]
    public private(set) var drawPile: [Card]
    public private(set) var discardPile: [Card] = []
    public private(set) var currentPlayerID = 0
    public private(set) var phase: GamePhase = .drawing
    public private(set) var log: [String] = []
    public var recentActivity: [String] { Array(log.suffix(3)) }
    public private(set) var winner: WinningSide?
    public private(set) var hasUsedSlash = false
    public private(set) var hasUsedWine = false
    public private(set) var nextSlashDamage = 1

    private var random: SeededGenerator
    private var dyingPasses = 0
    private var dyingSourceID: Int?
    private var dyingCause = "伤害"
    private var pendingMassTargets: [Int] = []
    private var pendingMassKind: CardKind = .arrows
    private var requiredResponse: CardKind = .dodge
    public private(set) var harvestChoices: [Card] = []
    private var pendingHarvestPlayers: [Int] = []
    private var pendingHarvestTrick: Card?
    private var pendingHarvestSourceID: Int?
    private var pendingTrick: PendingTrick?

    public static func newGame(seed: UInt64 = UInt64.random(in: 1...UInt64.max), hands: [[CardKind]]? = nil, startingHP: [Int]? = nil, startingEquipment: [[CardKind]]? = nil, startingDelayedTricks: [[CardKind]]? = nil, humanGeneral: General? = .caoCao, humanRole: Role? = .lord, generalPool: [General] = [.caoCao, .simaYi, .zhangFei, .zhaoYun], playerCount: Int = 4) -> GameEngine {
        GameEngine(seed: seed, hands: hands, startingHP: startingHP, startingEquipment: startingEquipment, startingDelayedTricks: startingDelayedTricks, humanGeneral: humanGeneral, humanRole: humanRole, generalPool: generalPool, playerCount: playerCount)
    }

    private init(seed: UInt64, hands: [[CardKind]]?, startingHP: [Int]?, startingEquipment: [[CardKind]]?, startingDelayedTricks: [[CardKind]]?, humanGeneral: General?, humanRole: Role?, generalPool: [General], playerCount: Int) {
        random = SeededGenerator(seed: seed)
        let count = IdentityConfiguration.supportedPlayerCounts.contains(playerCount) ? playerCount : 4
        var roles = IdentityConfiguration.roles(forPlayerCount: count)!
        roles.shuffle(using: &random)
        if let humanRole, let selected = roles.firstIndex(of: humanRole) { roles.swapAt(0, selected) }
        var availableGenerals = General.allCases.filter { generalPool.contains($0) }
        if let humanGeneral, !availableGenerals.contains(humanGeneral) { availableGenerals.append(humanGeneral) }
        for general in General.allCases where availableGenerals.count < count && !availableGenerals.contains(general) {
            availableGenerals.append(general)
        }
        availableGenerals.shuffle(using: &random)
        let selectedGeneral = humanGeneral ?? availableGenerals.removeFirst()
        availableGenerals.removeAll { $0 == selectedGeneral }
        let generals = [selectedGeneral] + Array(availableGenerals.prefix(count - 1))
        players = roles.enumerated().map { index, role in
            Player(id: index, name: index == 0 ? "你" : "电脑\(index)", role: role, isHuman: index == 0, general: generals[index], hp: generals[index].maxHP + (role == .lord ? 1 : 0))
        }
        log = ["你是\(players[0].role.title)，武将\(players[0].general.title)。观察行动，完成身份目标。"]
        if let startingHP, startingHP.count == players.count {
            for index in players.indices { players[index].hp = min(players[index].maxHP, max(0, startingHP[index])) }
        }
        allCards = StandardDeck.cards
        var cards = allCards
        cards.shuffle(using: &random)
        if let hands, hands.count == players.count {
            for (index, kinds) in hands.enumerated() {
                players[index].hand = kinds.map { kind in
                    let physicalCard = cards.removeFirst()
                    let card = Card(id: physicalCard.id, kind: kind, suit: physicalCard.suit, rank: physicalCard.rank)
                    return card
                }
            }
        } else {
            for _ in 0..<4 {
                for index in players.indices {
                    players[index].hand.append(cards.removeFirst())
                }
            }
        }
        if let startingEquipment, startingEquipment.count == players.count {
            for (playerID, kinds) in startingEquipment.enumerated() {
                for kind in kinds {
                    guard let slot = kind.equipmentSlot, players[playerID].equipment[slot] == nil else { continue }
                    let physical = cards.removeFirst()
                    players[playerID].equipment[slot] = Card(id: physical.id, kind: kind, suit: physical.suit, rank: physical.rank)
                }
            }
        }
        if let startingDelayedTricks, startingDelayedTricks.count == players.count {
            for (playerID, kinds) in startingDelayedTricks.enumerated() {
                for kind in kinds where [.lightning, .indulgence].contains(kind) {
                    let physical = cards.removeFirst()
                    players[playerID].delayedTricks.append(Card(id: physical.id, kind: kind, suit: physical.suit, rank: physical.rank))
                }
            }
        }
        drawPile = cards
    }

    public var currentPlayer: Player { players[currentPlayerID] }
    public var human: Player { players[0] }
    public var currentAttackerID: Int? {
        if case let .awaitingDodge(_, attackerID) = phase { attackerID }
        else { nil }
    }
    public var cardCounts: [CardCategory: Int] { StandardDeck.categoryCounts }
    public var responseCardKind: CardKind { requiredResponse }
    public var trickResponseSummary: String? {
        guard let trick = pendingTrick else { return nil }
        let source = players[trick.sourceID].isHuman ? "你" : players[trick.sourceID].general.title
        guard let targetID = trick.targetID else { return "\(source) 使用【\(trick.card.title)】" }
        let target = players[targetID].isHuman ? "你" : players[targetID].general.title
        return "\(source) 对 \(target) 使用【\(trick.card.title)】"
    }

    public var targetCardOptions: [TargetCardOption] {
        guard case let .choosingTargetCard(_, targetID, _) = phase else { return [] }
        return targetOptions(for: targetID)
    }

    public static func eightTrigramsDodges(with suit: Suit) -> Bool { suit.isRed }

    public mutating func drawForTurn() throws {
        guard phase == .drawing, currentPlayer.isAlive else { throw GameError.wrongPhase }
        let skipsAction = resolveDelayedTricks(for: currentPlayerID)
        if case .dying = phase { return }
        let drawCount = currentPlayer.general == .zhouYu ? 3 : (currentPlayer.general == .xuChu ? 1 : 2)
        draw(drawCount, for: currentPlayerID)
        phase = .action
        hasUsedSlash = false
        hasUsedWine = false
        nextSlashDamage = 1
        log.append("\(currentPlayer.name) 摸了\(drawCount)张牌。")
        if skipsAction { log.append("乐不思蜀生效，跳过出牌阶段。"); try endTurn() }
    }

    public mutating func play(cardID: Int, targetID: Int? = nil) throws {
        guard phase == .action else { throw GameError.wrongPhase }
        guard let cardIndex = currentPlayer.hand.firstIndex(where: { $0.id == cardID }) else { throw GameError.missingCard }
        let card = currentPlayer.hand[cardIndex]
        switch card.kind {
        case .slash:
            try useSlash(at: cardIndex, targetID: targetID)
        case .peach:
            try usePeach(at: cardIndex, targetID: targetID)
        case .wine:
            try useWine(at: cardIndex, targetID: targetID)
        case .dodge:
            if currentPlayer.general == .zhaoYun { try useSlash(at: cardIndex, targetID: targetID) }
            else { throw GameError.invalidCard }
        case .lightning, .indulgence, .barbarianInvasion, .arrows, .harvest, .godSalvation,
             .snatch, .dismantle, .duel, .collateral, .amazingGrace:
            try useTrick(cardIndex: cardIndex, targetID: targetID)
        case .nullification:
            throw GameError.invalidCard
        default:
            try equip(cardIndex: cardIndex)
        }
    }

    public mutating func respondToSlash(withDodge: Bool) throws {
        guard case let .awaitingDodge(targetID, _) = phase else { throw GameError.wrongPhase }
        let attackerID: Int
        if case let .awaitingDodge(_, source) = phase { attackerID = source } else { throw GameError.wrongPhase }
        var dodged = false
        if withDodge, let index = responseIndex(for: targetID) {
            discardPile.append(players[targetID].hand.remove(at: index))
            log.append("\(players[targetID].name) 打出【\(requiredResponse.title)】，抵消了\(players[attackerID].name) 对其使用的杀。")
            dodged = true
        } else if withDodge, requiredResponse == .dodge, players[targetID].equipment[.armor]?.kind == .eightTrigrams {
            dodged = judgeEightTrigrams(for: targetID, against: attackerID, attack: "杀")
        }
        if !dodged {
            let damage = attackerID == currentPlayerID ? nextSlashDamage : 1
            dealDamage(to: targetID, from: attackerID, amount: damage, cause: "杀")
        }
        if attackerID == currentPlayerID { nextSlashDamage = 1 }
        if winner != nil { phase = .gameOver }
        else if case .dying = phase { return }
        else if !pendingMassTargets.isEmpty { resolveNextMassTarget() }
        else { phase = .action }
    }

    public mutating func respondToDying(withPeach: Bool) throws {
        guard case let .dying(targetID, responderID) = phase else { throw GameError.wrongPhase }
        if withPeach {
            guard let index = players[responderID].hand.firstIndex(where: { $0.kind == .peach }) else { throw GameError.missingCard }
            discardPile.append(players[responderID].hand.remove(at: index))
            players[targetID].hp += 1
            log.append("\(players[responderID].name) 对濒死的 \(players[targetID].name) 使用桃。")
            dyingPasses = 0
            if players[targetID].hp > 0 { phase = .action; return }
        } else {
            log.append("\(players[responderID].name) 没有对 \(players[targetID].name) 使用桃。")
        }
        advanceDying(targetID: targetID, responderID: responderID)
        if case .action = phase, !pendingMassTargets.isEmpty { resolveNextMassTarget() }
    }

    public mutating func chooseHarvest(cardID: Int, by playerID: Int) throws {
        guard case let .choosingHarvest(recipientID) = phase, recipientID == playerID else { throw GameError.wrongPhase }
        guard let choiceIndex = harvestChoices.firstIndex(where: { $0.id == cardID }) else { throw GameError.invalidCard }
        let card = harvestChoices.remove(at: choiceIndex)
        players[playerID].hand.append(card)
        log.append("\(players[playerID].name) 从五谷丰登中获得【\(card.title)】。")
        pendingHarvestPlayers.removeFirst()
        if let nextPlayer = pendingHarvestPlayers.first {
            phase = .choosingHarvest(playerID: nextPlayer)
        } else {
            finishHarvest()
        }
    }

    public mutating func chooseTargetCard(cardID: Int) throws {
        guard case let .choosingTargetCard(sourceID, targetID, kind) = phase, sourceID == 0 else {
            throw GameError.wrongPhase
        }
        guard [.snatch, .dismantle].contains(kind), targetCardOptions.contains(where: { $0.id == cardID }),
              let card = removeTargetCard(cardID, from: targetID) else { throw GameError.invalidCard }
        moveChosenCard(card, from: targetID, to: sourceID, using: kind)
        phase = .action
    }

    public mutating func chooseCollateralTarget(_ targetID: Int) throws {
        guard case let .choosingCollateralTarget(sourceID, weaponOwnerID) = phase,
              collateralTargetCandidates.contains(targetID) else { throw GameError.invalidTarget }
        phase = .awaitingCollateralSlash(sourceID: sourceID, weaponOwnerID: weaponOwnerID, targetID: targetID)
        if !players[weaponOwnerID].isHuman {
            try respondToCollateral(withSlash: players[weaponOwnerID].hand.contains { $0.kind == .slash })
        }
    }

    public mutating func respondToCollateral(withSlash: Bool) throws {
        guard case let .awaitingCollateralSlash(sourceID, weaponOwnerID, targetID) = phase else {
            throw GameError.wrongPhase
        }
        if withSlash, let slashIndex = players[weaponOwnerID].hand.firstIndex(where: { $0.kind == .slash }),
           canTarget(targetID, with: .slash, from: weaponOwnerID) {
            discardPile.append(players[weaponOwnerID].hand.remove(at: slashIndex))
            log.append("\(players[weaponOwnerID].name) 对 \(players[targetID].name) 使用杀（借刀杀人）。")
            requiredResponse = .dodge
            phase = .awaitingDodge(targetID: targetID, attackerID: weaponOwnerID)
            if !players[targetID].isHuman { try respondToSlash(withDodge: canRespond(for: targetID)) }
        } else if let weapon = players[weaponOwnerID].equipment.removeValue(forKey: .weapon) {
            players[sourceID].hand.append(weapon)
            log.append("\(players[weaponOwnerID].name) 未能对 \(players[targetID].name) 使用杀，将【\(weapon.title)】交给\(players[sourceID].name)（借刀杀人）。")
            phase = .action
        } else {
            phase = .action
        }
    }

    public mutating func endTurn() throws {
        guard phase == .action else { throw GameError.wrongPhase }
        let keepsHand = currentPlayer.general == .lvMeng && !hasUsedSlash
        let excess = keepsHand ? 0 : max(0, currentPlayer.hand.count - currentPlayer.hp)
        if excess > 0 {
            let removed = players[currentPlayerID].hand.prefix(excess)
            discardPile.append(contentsOf: removed)
            players[currentPlayerID].hand.removeFirst(excess)
            log.append("\(currentPlayer.name) 弃置了 \(excess) 张牌（手牌不能多于体力）。")
        }
        guard winner == nil else { phase = .gameOver; return }
        currentPlayerID = nextLivingPlayer(after: currentPlayerID)
        phase = .drawing
        log.append("轮到 \(currentPlayer.name)。")
    }

    public mutating func playAITurns() {
        while advanceAI() {}
    }

    @discardableResult
    public mutating func advanceAI() -> Bool {
        guard winner == nil else { return false }
        if case let .awaitingDuelSlash(responderID, _) = phase {
            guard !players[responderID].isHuman else { return false }
            try? respondToDuel(withSlash: players[responderID].hand.contains { $0.kind == .slash })
            return true
        }
        if case let .respondingToTrick(responderID) = phase {
            guard !players[responderID].isHuman else { return false }
            let shouldNullify = players[responderID].hand.contains { $0.kind == .nullification }
                && (pendingTrick?.negationCount.isMultiple(of: 2) == false
                    || pendingTrick.map { !sameTeam(players[responderID].role, players[$0.sourceID].role) } == true)
            try? respondToTrick(withNullification: shouldNullify)
            return true
        }
        if case let .choosingHarvest(playerID) = phase {
            guard !players[playerID].isHuman, let card = bestHarvestChoice(for: playerID) else { return false }
            try? chooseHarvest(cardID: card.id, by: playerID)
            return true
        }
        if case let .dying(targetID, responderID) = phase {
            if players[responderID].isHuman { return false }
            let canSave = players[responderID].hand.contains(where: { $0.kind == .peach })
                && (sameTeam(players[responderID].role, players[targetID].role) || responderID == targetID)
            try? respondToDying(withPeach: canSave)
            return true
        }
        if case let .awaitingDodge(targetID, _) = phase {
            if players[targetID].isHuman { return false }
            try? respondToSlash(withDodge: canRespond(for: targetID))
            return true
        }
        guard !currentPlayer.isHuman else { return false }
        if phase == .drawing { try? drawForTurn(); return true }
        if phase == .action {
            if performAIAction() { return true }
            try? endTurn()
            return true
        }
        return false
    }

    public mutating func continueAfterHumanResponse() {
        // The caller advances the computer one visible action at a time.
    }

    private mutating func useSlash(at index: Int, targetID: Int?) throws {
        guard slashLimitAllows(currentPlayerID) else { throw GameError.slashAlreadyUsed }
        guard let targetID, isLegalTarget(targetID, from: currentPlayerID) else { throw GameError.outOfRange }
        let slash = players[currentPlayerID].hand.remove(at: index)
        discardPile.append(slash)
        hasUsedSlash = true
        log.append("\(currentPlayer.name) 对 \(players[targetID].name) 使用杀。")
        let ignoresArmor = players[currentPlayerID].equipment[.weapon]?.kind == .QinggangSword
        if !ignoresArmor, players[targetID].equipment[.armor]?.kind == .blackShield, !slash.suit.isRed {
            log.append("仁王盾阻挡了黑色杀；\(players[targetID].name) 不受此杀影响。")
            phase = .action
            return
        }
        if players[targetID].isHuman {
            requiredResponse = .dodge
            if canRespond(for: targetID) { phase = .awaitingDodge(targetID: targetID, attackerID: currentPlayerID) }
            else { phase = .awaitingDodge(targetID: targetID, attackerID: currentPlayerID); try respondToSlash(withDodge: false) }
        } else {
            requiredResponse = .dodge
            phase = .awaitingDodge(targetID: targetID, attackerID: currentPlayerID)
            try respondToSlash(withDodge: canRespond(for: targetID))
        }
    }

    private mutating func usePeach(at index: Int, targetID: Int?) throws {
        let target = targetID ?? currentPlayerID
        guard target == currentPlayerID, players[target].isAlive, players[target].hp < players[target].maxHP else { throw GameError.invalidTarget }
        discardPile.append(players[currentPlayerID].hand.remove(at: index))
        players[target].hp = min(players[target].maxHP, players[target].hp + 1)
        log.append("\(currentPlayer.name) 对 \(players[target].name) 使用桃，回复 1 点体力。")
    }

    private mutating func useWine(at index: Int, targetID: Int?) throws {
        guard (targetID == nil || targetID == currentPlayerID), !hasUsedWine else { throw GameError.invalidTarget }
        discardPile.append(players[currentPlayerID].hand.remove(at: index))
        hasUsedWine = true
        nextSlashDamage = 2
        log.append("\(currentPlayer.name) 使用酒，本回合下一张杀伤害 +1。")
    }

    private mutating func equip(cardIndex: Int) throws {
        let card = players[currentPlayerID].hand.remove(at: cardIndex)
        guard let slot = card.kind.equipmentSlot else { throw GameError.invalidCard }
        if let old = players[currentPlayerID].equipment[slot] { discardPile.append(old) }
        players[currentPlayerID].equipment[slot] = card
        log.append("\(currentPlayer.name) 装备了\(card.title)。")
    }

    private mutating func useTrick(cardIndex: Int, targetID: Int?) throws {
        let card = players[currentPlayerID].hand[cardIndex]
        let sourceID = currentPlayerID
        let needsTarget = [.snatch, .dismantle, .duel, .collateral, .indulgence].contains(card.kind)
        if needsTarget {
            guard let targetID, canTarget(targetID, with: card.kind, from: sourceID) else { throw GameError.outOfRange }
        }
        players[sourceID].hand.remove(at: cardIndex)
        let trick = PendingTrick(card: card, sourceID: sourceID, targetID: targetID)
        log.append(needsTarget
            ? "\(players[sourceID].name) 对 \(players[targetID!].name) 使用锦囊【\(card.title)】。"
            : "\(players[sourceID].name) 使用锦囊【\(card.title)】。")
        if let responderID = nextTrickResponder(after: sourceID, for: trick) {
            pendingTrick = trick
            phase = .respondingToTrick(responderID: responderID)
            log.append("无懈可击响应窗口开启：有无懈可击的角色可以反制【\(card.title)】。")
        } else {
            resolveTrick(card, sourceID: sourceID, targetID: targetID)
        }
    }

    public mutating func respondToTrick(withNullification: Bool) throws {
        guard case let .respondingToTrick(responderID) = phase, var trick = pendingTrick else { throw GameError.wrongPhase }
        if withNullification {
            guard let index = players[responderID].hand.firstIndex(where: { $0.kind == .nullification }) else { throw GameError.missingCard }
            let card = players[responderID].hand.remove(at: index)
            discardPile.append(card)
            trick.negationCount += 1
            trick.passedResponders.removeAll()
            let targetDescription = trick.targetID.map { " 对 \(players[$0].name)" } ?? ""
            log.append("\(players[responderID].name) 使用无懈可击，反制了\(players[trick.sourceID].name)\(targetDescription)使用的【\(trick.card.title)】。")
        } else {
            trick.passedResponders.insert(responderID)
            log.append("\(players[responderID].name) 放弃使用无懈可击响应【\(trick.card.title)】。")
        }
        pendingTrick = trick
        if let nextResponder = nextTrickResponder(after: responderID, for: trick) {
            phase = .respondingToTrick(responderID: nextResponder)
        } else {
            pendingTrick = nil
            finishPendingTrick(trick)
        }
    }

    private func nextTrickResponder(after playerID: Int, for trick: PendingTrick) -> Int? {
        for offset in 1...players.count {
            let id = (playerID + offset) % players.count
            if players[id].isAlive, !trick.passedResponders.contains(id),
               players[id].hand.contains(where: { $0.kind == .nullification }) { return id }
        }
        return nil
    }

    private mutating func finishPendingTrick(_ trick: PendingTrick) {
        guard trick.negationCount.isMultiple(of: 2) else {
            discardPile.append(trick.card)
            log.append("【\(trick.card.title)】被无懈可击抵消，不结算效果。")
            phase = .action
            return
        }
        resolveTrick(trick.card, sourceID: trick.sourceID, targetID: trick.targetID)
    }

    public mutating func respondToDuel(withSlash: Bool) throws {
        guard case let .awaitingDuelSlash(responderID, challengerID) = phase else { throw GameError.wrongPhase }
        if withSlash {
            guard let index = players[responderID].hand.firstIndex(where: { $0.kind == .slash }) else { throw GameError.missingCard }
            discardPile.append(players[responderID].hand.remove(at: index))
            log.append("\(players[responderID].name) 对 \(players[challengerID].name) 使用杀，继续决斗。")
            phase = .awaitingDuelSlash(responderID: challengerID, challengerID: responderID)
        } else {
            log.append("\(players[responderID].name) 无法对 \(players[challengerID].name) 的决斗打出杀，受到 1 点伤害。")
            phase = .action
            dealDamage(to: responderID, from: challengerID, amount: 1, cause: "决斗")
        }
    }

    private mutating func resolveTrick(_ card: Card, sourceID: Int, targetID: Int?) {
        phase = .action
        switch card.kind {
        case .indulgence:
            guard let targetID else { return }
            players[targetID].delayedTricks.append(card)
            log.append("乐不思蜀进入\(players[targetID].name) 的判定区。")
        case .lightning:
            players[sourceID].delayedTricks.append(card)
            log.append("闪电进入\(players[sourceID].name) 的判定区。")
        case .harvest:
            pendingHarvestTrick = card
            pendingHarvestSourceID = sourceID
        case .nullification:
            return
        default:
            discardPile.append(card)
        }
        switch card.kind {
        case .amazingGrace: draw(2, for: sourceID); log.append("\(players[sourceID].name) 摸两张牌。")
        case .godSalvation:
            for id in players.indices where players[id].isAlive && players[id].hp < players[id].maxHP { players[id].hp += 1 }
            log.append("所有受伤角色各回复 1 点体力。")
        case .snatch, .dismantle:
            guard let targetID else { return }
            if hasMovableCard(targetID) {
                if players[sourceID].isHuman {
                    phase = .choosingTargetCard(sourceID: sourceID, targetID: targetID, kind: card.kind)
                } else if let option = preferredAICardChoice(from: targetID) {
                    guard let selected = removeTargetCard(option.id, from: targetID) else { return }
                    moveChosenCard(selected, from: targetID, to: sourceID, using: card.kind)
                }
            } else {
                log.append("\(players[sourceID].name) 对 \(players[targetID].name) 使用【\(card.title)】，但目标没有可移动的牌。")
            }
        case .duel:
            if let targetID {
                phase = .awaitingDuelSlash(responderID: targetID, challengerID: sourceID)
            }
        case .barbarianInvasion, .arrows:
            pendingMassKind = card.kind
            requiredResponse = card.kind == .barbarianInvasion ? .slash : .dodge
            pendingMassTargets = players.indices.filter { $0 != sourceID && players[$0].isAlive }
            resolveNextMassTarget()
        case .lightning, .indulgence: break
        case .collateral:
            if let weaponOwnerID = targetID {
                if players[sourceID].isHuman {
                    phase = .choosingCollateralTarget(sourceID: sourceID, weaponOwnerID: weaponOwnerID)
                } else if let victim = collateralCandidates(for: weaponOwnerID).first(where: {
                    !sameTeam(players[$0].role, players[sourceID].role)
                }) ?? collateralCandidates(for: weaponOwnerID).first {
                    phase = .awaitingCollateralSlash(sourceID: sourceID, weaponOwnerID: weaponOwnerID, targetID: victim)
                    try? respondToCollateral(withSlash: players[weaponOwnerID].hand.contains { $0.kind == .slash })
                }
            }
        case .harvest:
            beginHarvest(from: sourceID)
        default: return
        }
        if players[sourceID].general == .huangYueYing,
           ![.lightning, .indulgence, .nullification, .harvest].contains(card.kind) {
            draw(1, for: sourceID)
            log.append("集智：黄月英摸一张牌。")
        }
    }

    private mutating func resolveNextMassTarget() {
        while !pendingMassTargets.isEmpty {
            let targetID = pendingMassTargets.removeFirst()
            guard players[targetID].isAlive else { continue }
            requiredResponse = pendingMassKind == .barbarianInvasion ? .slash : .dodge
            if let response = responseIndex(for: targetID) {
                if players[targetID].isHuman {
                    phase = .awaitingDodge(targetID: targetID, attackerID: currentPlayerID)
                    log.append("\(players[targetID].name) 需要响应【\(pendingMassKind.title)】。")
                    return
                }
                discardPile.append(players[targetID].hand.remove(at: response))
                log.append("\(players[targetID].name) 打出【\(requiredResponse.title)】响应【\(pendingMassKind.title)】。")
            } else if requiredResponse == .dodge, players[targetID].equipment[.armor]?.kind == .eightTrigrams {
                let success = judgeEightTrigrams(for: targetID, against: currentPlayerID, attack: pendingMassKind.title)
                if !success { dealDamage(to: targetID, from: currentPlayerID, amount: 1, cause: pendingMassKind.title) }
            } else {
                dealDamage(to: targetID, from: currentPlayerID, amount: 1, cause: pendingMassKind.title)
                if case .dying = phase { return }
            }
        }
        phase = winner == nil ? .action : .gameOver
    }

    private mutating func dealDamage(to targetID: Int, from sourceID: Int?, amount: Int, cause: String) {
        players[targetID].hp -= amount
        if sourceID == nil {
            log.append("\(players[targetID].name) 因【\(cause)】受到 \(amount) 点无来源雷电伤害。")
        } else if sourceID == targetID {
            log.append("\(players[targetID].name) 因【\(cause)】受到 \(amount) 点伤害。")
        } else {
            log.append("\(players[sourceID!].name) 使用【\(cause)】对 \(players[targetID].name) 造成 \(amount) 点伤害。")
        }
        switch players[targetID].general {
        case .caoCao:
            if let card = discardPile.popLast() { players[targetID].hand.append(card); log.append("奸雄：曹操获得造成伤害的牌【\(card.title)】。") }
        case .simaYi:
            if let sourceID, sourceID != targetID, !players[sourceID].hand.isEmpty {
                let card = players[sourceID].hand.removeFirst(); players[targetID].hand.append(card)
                log.append("反馈：司马懿获得\(players[sourceID].name) 一张手牌。")
            }
        default: break
        }
        if players[targetID].hp <= 0 {
            dyingSourceID = sourceID
            dyingCause = cause
            beginDying(targetID)
        }
    }

    private mutating func resolveDelayedTricks(for playerID: Int) -> Bool {
        let delayed = players[playerID].delayedTricks
        players[playerID].delayedTricks.removeAll()
        var skipsAction = false
        for card in delayed {
            guard let judgment = takeTopCards(1).first else {
                discardPile.append(card)
                log.append("\(players[playerID].name) 的【\(card.title)】没有判定牌，未产生效果。")
                continue
            }
            discardPile.append(judgment)
            if card.kind == .indulgence {
                discardPile.append(card)
                skipsAction = judgment.suit != .heart
                let result = skipsAction ? "跳过出牌阶段" : "红桃，不跳过出牌阶段"
                log.append("\(players[playerID].name) 乐不思蜀判定翻出\(judgment.judgmentDescription)：\(result)。")
            } else if card.kind == .lightning {
                if judgment.suit == .spade && (2...9).contains(judgment.rank) {
                    discardPile.append(card)
                    log.append("\(players[playerID].name) 闪电判定翻出\(judgment.judgmentDescription)：命中黑桃 2–9。")
                    dealDamage(to: playerID, from: nil, amount: 3, cause: "闪电")
                    if case .dying = phase { return skipsAction }
                } else if let nextPlayer = nextLightningTarget(after: playerID) {
                    players[nextPlayer].delayedTricks.append(card)
                    log.append("\(players[playerID].name) 闪电判定翻出\(judgment.judgmentDescription)：未命中，闪电传给\(players[nextPlayer].name)。")
                } else {
                    players[playerID].delayedTricks.append(card)
                    log.append("\(players[playerID].name) 闪电判定翻出\(judgment.judgmentDescription)：未命中，场上无其他合法目标，闪电留在其判定区。")
                }
            }
        }
        return skipsAction
    }

    private func nextLightningTarget(after playerID: Int) -> Int? {
        for offset in 1..<players.count {
            let candidate = (playerID + offset) % players.count
            if players[candidate].isAlive && !players[candidate].delayedTricks.contains(where: { $0.kind == .lightning }) {
                return candidate
            }
        }
        return nil
    }

    private mutating func judgeEightTrigrams(for targetID: Int, against attackerID: Int, attack: String) -> Bool {
        guard let card = takeTopCards(1).first else {
            log.append("\(players[targetID].name) 的八卦阵判定失败：牌堆没有判定牌。")
            return false
        }
        discardPile.append(card)
        let success = Self.eightTrigramsDodges(with: card.suit)
        let result = success
            ? "红色，视为使用【闪】，抵消\(players[attackerID].name) 对 \(players[targetID].name) 使用的【\(attack)】"
            : "黑色，判定失败，\(players[attackerID].name) 对 \(players[targetID].name) 使用的【\(attack)】命中"
        log.append("\(players[targetID].name) 发动八卦阵：翻出\(card.judgmentDescription)（\(result)）。")
        return success
    }

    private func targetOptions(for playerID: Int) -> [TargetCardOption] {
        guard players.indices.contains(playerID) else { return [] }
        let target = players[playerID]
        let hand = target.hand.map { TargetCardOption(card: $0, zone: .hand) }
        let equipment = EquipmentSlot.allCases.compactMap { target.equipment[$0] }
            .map { TargetCardOption(card: $0, zone: .equipment) }
        let judgment = target.delayedTricks.map { TargetCardOption(card: $0, zone: .judgment) }
        return hand + equipment + judgment
    }

    private func preferredAICardChoice(from playerID: Int) -> TargetCardOption? {
        let options = targetOptions(for: playerID)
        return options.first { $0.zone != .hand } ?? options.first
    }

    private mutating func removeTargetCard(_ cardID: Int, from playerID: Int) -> Card? {
        if let index = players[playerID].hand.firstIndex(where: { $0.id == cardID }) {
            return players[playerID].hand.remove(at: index)
        }
        if let slot = EquipmentSlot.allCases.first(where: { players[playerID].equipment[$0]?.id == cardID }) {
            return players[playerID].equipment.removeValue(forKey: slot)
        }
        if let index = players[playerID].delayedTricks.firstIndex(where: { $0.id == cardID }) {
            return players[playerID].delayedTricks.remove(at: index)
        }
        return nil
    }

    private mutating func moveChosenCard(_ card: Card, from targetID: Int, to sourceID: Int, using kind: CardKind) {
        if kind == .snatch {
            players[sourceID].hand.append(card)
            log.append("\(players[sourceID].name) 从 \(players[targetID].name) 处获得【\(card.title)】（顺手牵羊）。")
        } else {
            discardPile.append(card)
            log.append("\(players[sourceID].name) 弃置了 \(players[targetID].name) 的【\(card.title)】（过河拆桥）。")
        }
    }

    private func responseIndex(for playerID: Int) -> Int? {
        players[playerID].hand.firstIndex { $0.kind == requiredResponse || (requiredResponse == .dodge && players[playerID].general == .zhaoYun && $0.kind == .slash) }
    }

    private func canRespond(for playerID: Int) -> Bool {
        responseIndex(for: playerID) != nil
            || (requiredResponse == .dodge && players[playerID].equipment[.armor]?.kind == .eightTrigrams)
    }

    func weaponRange(_ kind: CardKind) -> Int {
        switch kind {
        case .doubleSword, .iceSword, .QinggangSword: 2
        case .greenDragonBlade, .serpentSpear, .axe: 3
        case .halberd: 4
        case .kylinBow: 5
        default: 1
        }
    }

    private func slashLimitAllows(_ playerID: Int) -> Bool {
        !hasUsedSlash || players[playerID].general == .zhangFei || players[playerID].equipment[.weapon]?.kind == .crossbow
    }

    private mutating func performAIAction() -> Bool {
        let id = currentPlayerID
        if let card = players[id].hand.first(where: { card in
            guard let slot = card.kind.equipmentSlot else { return false }
            return players[id].equipment[slot] == nil
        }) {
            try? play(cardID: card.id)
            return true
        }
        if players[id].hp < players[id].maxHP, let peach = players[id].hand.first(where: { $0.kind == .peach }) {
            try? play(cardID: peach.id, targetID: id)
            return true
        }
        if let wine = players[id].hand.first(where: { $0.kind == .wine }), !hasUsedWine,
           players[id].hand.contains(where: { $0.kind == .slash }) {
            try? play(cardID: wine.id)
            return true
        }
        if let trick = players[id].hand.first(where: {
            [.amazingGrace, .godSalvation, .snatch, .dismantle, .duel, .collateral, .indulgence, .lightning, .barbarianInvasion, .arrows, .harvest].contains($0.kind)
        }) {
            let target = [.snatch, .dismantle, .duel, .collateral, .indulgence].contains(trick.kind) ? aiTarget(for: id, using: trick.kind) : nil
            let targetNeeded = [.snatch, .dismantle, .duel, .collateral, .indulgence].contains(trick.kind)
            if !targetNeeded || target != nil {
                try? play(cardID: trick.id, targetID: target)
                return true
            }
        }
        guard let slash = players[id].hand.first(where: { $0.kind == .slash }), slashLimitAllows(id),
              let target = aiTarget(for: id) else { return false }
        try? play(cardID: slash.id, targetID: target)
        return true
    }

    private func aiTarget(for id: Int, using kind: CardKind? = nil) -> Int? {
        let candidates = players.filter { player in
            kind.map { canTarget(player.id, with: $0, from: id) } ?? isLegalTarget(player.id, from: id)
        }
        let enemies = candidates.filter { !sameTeam(players[id].role, $0.role) }
        return enemies.first(where: { $0.isHuman })?.id ?? enemies.first?.id
    }

    private func sameTeam(_ lhs: Role, _ rhs: Role) -> Bool {
        let loyal = [Role.lord, .loyalist]
        if loyal.contains(lhs) { return loyal.contains(rhs) }
        return lhs == .rebel && rhs == .rebel
    }

    private mutating func eliminate(_ id: Int, by attackerID: Int) {
        players[id].isAlive = false
        discardPile.append(contentsOf: players[id].hand)
        players[id].hand.removeAll()
        if attackerID == id {
            log.append("\(players[id].name) 因【\(dyingCause)】阵亡。")
        } else {
            log.append("\(players[attackerID].name) 击杀了 \(players[id].name)（【\(dyingCause)】）。")
        }
        if players[id].role == .rebel, players[attackerID].isAlive {
            draw(3, for: attackerID)
            log.append("消灭反贼，\(players[attackerID].name) 摸三张牌。")
        } else if players[id].role == .loyalist, players[attackerID].role == .lord {
            discardPile.append(contentsOf: players[attackerID].hand)
            players[attackerID].hand.removeAll()
            log.append("主公误杀忠臣，弃置所有手牌。")
        }
        checkVictory()
    }

    private mutating func beginDying(_ targetID: Int) {
        dyingPasses = 0
        phase = .dying(targetID: targetID, responderID: targetID)
    }

    private mutating func advanceDying(targetID: Int, responderID: Int) {
        dyingPasses += 1
        let livingCount = players.filter(\.isAlive).count
        if dyingPasses >= livingCount {
            eliminate(targetID, by: dyingSourceID ?? targetID)
            dyingSourceID = nil
            dyingCause = "伤害"
            phase = winner == nil ? .action : .gameOver
            return
        }
        phase = .dying(targetID: targetID, responderID: nextLivingPlayer(after: responderID))
    }

    private mutating func checkVictory() {
        winner = Self.winner(for: players)
    }

    public static func winner(for players: [Player]) -> WinningSide? {
        let alive = players.filter(\.isAlive)
        if alive.count == 1, alive[0].role == .spy { return .spy }
        guard let lord = players.first(where: { $0.role == .lord }), lord.isAlive else { return .rebels }
        if !players.contains(where: { $0.isAlive && ($0.role == .rebel || $0.role == .spy) }) {
            return .lordAndLoyalist
        }
        return nil
    }

    private mutating func draw(_ count: Int, for playerID: Int) {
        players[playerID].hand.append(contentsOf: takeTopCards(count))
    }

    private mutating func beginHarvest(from sourceID: Int) {
        let living = players.indices.filter { players[$0].isAlive }
        let order = living.filter { $0 >= sourceID } + living.filter { $0 < sourceID }
        harvestChoices = takeTopCards(living.count)
        pendingHarvestPlayers = Array(order.prefix(harvestChoices.count))
        let revealed = harvestChoices.map { "【\($0.title)】" }.joined(separator: "、")
        log.append("五谷丰登亮出：\(revealed.isEmpty ? "牌堆已空" : revealed)。")
        if harvestChoices.isEmpty {
            finishHarvest()
        } else if let firstPlayer = pendingHarvestPlayers.first {
            phase = .choosingHarvest(playerID: firstPlayer)
        }
    }

    private mutating func finishHarvest() {
        if let trick = pendingHarvestTrick { discardPile.append(trick) }
        pendingHarvestTrick = nil
        if let sourceID = pendingHarvestSourceID, players[sourceID].general == .huangYueYing {
            draw(1, for: sourceID)
            log.append("集智：黄月英摸一张牌。")
        }
        pendingHarvestSourceID = nil
        pendingHarvestPlayers.removeAll()
        harvestChoices.removeAll()
        phase = .action
    }

    private mutating func takeTopCards(_ count: Int) -> [Card] {
        var cards: [Card] = []
        while cards.count < count {
            if drawPile.isEmpty, !discardPile.isEmpty {
                drawPile = discardPile.shuffled(using: &random)
                discardPile.removeAll()
            }
            guard !drawPile.isEmpty else { break }
            cards.append(drawPile.removeFirst())
        }
        return cards
    }

    private func bestHarvestChoice(for playerID: Int) -> Card? {
        harvestChoices.max { harvestValue($0, for: playerID) < harvestValue($1, for: playerID) }
    }

    private func harvestValue(_ card: Card, for playerID: Int) -> Int {
        switch card.kind {
        case .peach: players[playerID].hp < players[playerID].maxHP ? 100 : 15
        case .dodge: players[playerID].hand.contains { $0.kind == .dodge } ? 15 : 40
        case .slash: players[playerID].hand.contains { $0.kind == .slash } ? 20 : 35
        default: card.kind.equipmentSlot.map { players[playerID].equipment[$0] == nil ? 30 : 10 } ?? 5
        }
    }

    private func nextLivingPlayer(after id: Int) -> Int {
        for offset in 1...players.count {
            let next = (id + offset) % players.count
            if players[next].isAlive { return next }
        }
        return id
    }
}
