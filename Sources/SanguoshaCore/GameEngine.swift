import Foundation

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

    public static func newGame(seed: UInt64 = UInt64.random(in: 1...UInt64.max), hands: [[CardKind]]? = nil, startingHP: [Int]? = nil, humanGeneral: General? = .caoCao, humanRole: Role? = .lord, generalPool: [General] = [.caoCao, .simaYi, .zhangFei, .zhaoYun]) -> GameEngine {
        GameEngine(seed: seed, hands: hands, startingHP: startingHP, humanGeneral: humanGeneral, humanRole: humanRole, generalPool: generalPool)
    }

    private init(seed: UInt64, hands: [[CardKind]]?, startingHP: [Int]?, humanGeneral: General?, humanRole: Role?, generalPool: [General]) {
        random = SeededGenerator(seed: seed)
        var roles = Role.allCases
        roles.shuffle(using: &random)
        if let humanRole, let selected = roles.firstIndex(of: humanRole) { roles.swapAt(0, selected) }
        var availableGenerals = General.allCases.filter { generalPool.contains($0) }
        if let humanGeneral, !availableGenerals.contains(humanGeneral) { availableGenerals.append(humanGeneral) }
        for general in General.allCases where availableGenerals.count < 4 && !availableGenerals.contains(general) {
            availableGenerals.append(general)
        }
        availableGenerals.shuffle(using: &random)
        let selectedGeneral = humanGeneral ?? availableGenerals.removeFirst()
        availableGenerals.removeAll { $0 == selectedGeneral }
        let generals = [selectedGeneral] + Array(availableGenerals.prefix(3))
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
        drawPile = cards
    }

    public var currentPlayer: Player { players[currentPlayerID] }
    public var human: Player { players[0] }
    public var currentAttackerID: Int? {
        if case let .awaitingDodge(_, attackerID) = phase { attackerID }
        else { nil }
    }
    public var cardCounts: [CardCategory: Int] {
        Dictionary(uniqueKeysWithValues: CardCategory.allCases.map { category in
            (category, allCards.filter { $0.category == category }.count)
        })
    }
    public var responseCardKind: CardKind { requiredResponse }

    public static func eightTrigramsDodges(with suit: Suit) -> Bool { suit.isRed }

    public mutating func drawForTurn() throws {
        guard phase == .drawing, currentPlayer.isAlive else { throw GameError.wrongPhase }
        let delayed = players[currentPlayerID].delayedTricks
        players[currentPlayerID].delayedTricks.removeAll()
        var skipsAction = false
        for card in delayed {
            discardPile.append(card)
            if card.kind == .indulgence {
                skipsAction = true
                log.append("\(currentPlayer.name) 判定乐不思蜀，本回合跳过出牌阶段。")
            } else if card.kind == .lightning {
                log.append("\(currentPlayer.name) 结算闪电判定。")
                dealDamage(to: currentPlayerID, from: currentPlayerID, amount: 1, cause: "闪电")
                if case .dying = phase { return }
            }
        }
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
             .nullification, .snatch, .dismantle, .duel, .collateral, .amazingGrace:
            try useTrick(cardIndex: cardIndex, targetID: targetID)
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
            dealDamage(to: targetID, from: attackerID, amount: nextSlashDamage, cause: "杀")
        }
        nextSlashDamage = 1
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
        discardPile.append(players[currentPlayerID].hand.remove(at: index))
        hasUsedSlash = true
        log.append("\(currentPlayer.name) 对 \(players[targetID].name) 使用杀。")
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
        guard players.indices.contains(target), players[target].isAlive, players[target].hp < players[target].maxHP else { throw GameError.invalidTarget }
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
        log.append("\(players[sourceID].name) 使用锦囊【\(card.title)】。")
        switch card.kind {
        case .indulgence:
            guard let targetID else { throw GameError.invalidTarget }
            players[targetID].delayedTricks.append(card)
            log.append("乐不思蜀进入\(players[targetID].name) 的判定区。")
        case .lightning:
            players[sourceID].delayedTricks.append(card)
            log.append("闪电进入\(players[sourceID].name) 的判定区。")
        case .nullification:
            players[sourceID].hand.append(card)
            log.append("无懈可击等待响应锦囊。")
        case .harvest:
            pendingHarvestTrick = card
            pendingHarvestSourceID = sourceID
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
            if let stolen = takeRandomCard(from: targetID) {
                if card.kind == .snatch { players[sourceID].hand.append(stolen); log.append("获得了\(players[targetID].name) 的【\(stolen.title)】。") }
                else { discardPile.append(stolen); log.append("弃置了\(players[targetID].name) 的【\(stolen.title)】。") }
            }
        case .duel:
            if let targetID, let index = players[targetID].hand.firstIndex(where: { $0.kind == .slash }) {
                let response = players[targetID].hand.remove(at: index)
                discardPile.append(response)
                log.append("\(players[targetID].name) 以杀应对决斗；简化结算由发起者受到伤害。")
                dealDamage(to: sourceID, from: targetID, amount: 1, cause: "决斗")
            } else if let targetID {
                log.append("\(players[targetID].name) 无杀响应决斗。")
                dealDamage(to: targetID, from: sourceID, amount: 1, cause: "决斗")
            }
        case .barbarianInvasion, .arrows:
            pendingMassKind = card.kind
            requiredResponse = card.kind == .barbarianInvasion ? .slash : .dodge
            pendingMassTargets = players.indices.filter { $0 != sourceID && players[$0].isAlive }
            resolveNextMassTarget()
        case .lightning, .indulgence: break
        case .collateral:
            if let targetID, let weapon = players[targetID].equipment.removeValue(forKey: .weapon) {
                discardPile.append(weapon)
                log.append("借刀杀人：目标交出武器【\(weapon.title)】。")
            }
        case .harvest:
            beginHarvest(from: sourceID)
        case .nullification: break
        default: throw GameError.invalidCard
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

    private mutating func dealDamage(to targetID: Int, from sourceID: Int, amount: Int, cause: String) {
        players[targetID].hp -= amount
        if sourceID == targetID {
            log.append("\(players[targetID].name) 因【\(cause)】受到 \(amount) 点伤害。")
        } else {
            log.append("\(players[sourceID].name) 使用【\(cause)】对 \(players[targetID].name) 造成 \(amount) 点伤害。")
        }
        switch players[targetID].general {
        case .caoCao:
            if let card = discardPile.popLast() { players[targetID].hand.append(card); log.append("奸雄：曹操获得造成伤害的牌【\(card.title)】。") }
        case .simaYi:
            if sourceID != targetID, !players[sourceID].hand.isEmpty {
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

    private mutating func takeRandomCard(from playerID: Int) -> Card? {
        if !players[playerID].hand.isEmpty { return players[playerID].hand.removeFirst() }
        if let slot = players[playerID].equipment.keys.first { return players[playerID].equipment.removeValue(forKey: slot) }
        return nil
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
            [.amazingGrace, .godSalvation, .snatch, .dismantle, .indulgence, .lightning, .barbarianInvasion, .arrows, .harvest].contains($0.kind)
        }) {
            let target = [.snatch, .dismantle, .indulgence].contains(trick.kind) ? aiTarget(for: id) : nil
            let targetNeeded = [.snatch, .dismantle, .indulgence].contains(trick.kind)
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

    private func aiTarget(for id: Int) -> Int? {
        let candidates = players.filter { isLegalTarget($0.id, from: id) }
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
            eliminate(targetID, by: dyingSourceID ?? currentPlayerID)
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
