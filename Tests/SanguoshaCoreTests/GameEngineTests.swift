import XCTest
@testable import SanguoshaCore

final class GameEngineTests: XCTestCase {
    func testUserCanChooseNonLordIdentityAndGeneral() {
        let game = GameEngine.newGame(seed: 41, humanGeneral: .liuBei, humanRole: .rebel)

        XCTAssertEqual(game.human.role, .rebel)
        XCTAssertEqual(game.human.general, .liuBei)
        XCTAssertEqual(game.players.filter { $0.role == .lord }.count, 1)
        XCTAssertNotEqual(game.players.first { $0.role == .lord }?.id, 0)
    }

    func testLordBonusHealthBelongsToTheLordSeat() throws {
        let game = GameEngine.newGame(seed: 41, humanGeneral: .liuBei, humanRole: .rebel)
        let lord = try XCTUnwrap(game.players.first { $0.role == .lord })

        XCTAssertEqual(game.human.maxHP, game.human.general.maxHP)
        XCTAssertEqual(lord.maxHP, lord.general.maxHP + 1)
        XCTAssertEqual(lord.hp, lord.maxHP)
    }

    func testHealthStatusShowsEachGeneralMaximumAndCurrentHealth() {
        let threeHealth = GameEngine.newGame(seed: 41, humanGeneral: .simaYi, humanRole: .rebel)
        let fourHealth = GameEngine.newGame(seed: 41, humanGeneral: .guanYu, humanRole: .rebel)

        XCTAssertEqual(threeHealth.human.healthStatus, "3/3")
        XCTAssertEqual(fourHealth.human.healthStatus, "4/4")
    }

    func testVoiceCuesCoverPlayedCardsAndResponsesButSkipPassiveLogLines() {
        let events = [
            "张飞 对 赵云 使用杀。",
            "赵云 打出【闪】，响应了本次攻击。",
            "刘备 装备了诸葛连弩。",
            "周瑜 使用锦囊【决斗】。",
            "司马懿 使用无懈可击，反制了当前锦囊。",
            "孙权以杀应对决斗；简化结算由发起者受到伤害。",
            "赵云 受到 1 点伤害。"
        ]

        XCTAssertEqual(GameVoiceCue.lines(from: events), Array(events.prefix(6)))
    }

    func testVoiceUsesOpponentGeneralNamesAndFirstPersonForHumanActions() {
        let players = [
            Player(id: 0, name: "你", role: .rebel, isHuman: true, general: .guanYu),
            Player(id: 1, name: "电脑3", role: .lord, isHuman: false, general: .luXun)
        ]
        let events = ["你 对 电脑3 使用杀。", "电脑3 打出【闪】，响应了你的攻击。"]

        XCTAssertEqual(GameVoiceCue.spokenLines(from: events, players: players), [
            "我对陆逊使用杀。", "陆逊打出【闪】，响应了你的攻击。"
        ])
    }

    func testDismantleHistoryAndVoiceNameTheActorTargetAndDiscardedCard() throws {
        var game = GameEngine.newGame(seed: 327, hands: [[.dismantle], [.peach], [], []])
        try game.drawForTurn()
        let trick = try XCTUnwrap(game.human.hand.first { $0.kind == .dismantle })
        let targetName = game.players[1].general.title

        try game.play(cardID: trick.id, targetID: 1)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }

        let visible = GameLogPresentation.visibleLines(from: game.log, players: game.players)
        let spoken = GameVoiceCue.spokenLines(from: game.log, players: game.players)
        XCTAssertTrue(visible.contains("你 对 \(targetName) 使用锦囊【过河拆桥】。"), "\(visible)")
        XCTAssertTrue(visible.contains("你 弃置了 \(targetName) 的【桃】（过河拆桥）。"), "\(visible)")
        XCTAssertTrue(spoken.contains("我对\(targetName)使用锦囊【过河拆桥】。"), "\(spoken)")
        XCTAssertTrue(spoken.contains("我弃置了\(targetName)的【桃】（过河拆桥）。"), "\(spoken)")
    }

    func testSnatchHistoryAndVoiceNameTheActorTargetAndTakenCard() throws {
        var game = GameEngine.newGame(seed: 328, hands: [[.snatch], [.crossbow], [], []])
        try game.drawForTurn()
        let trick = try XCTUnwrap(game.human.hand.first { $0.kind == .snatch })
        let targetName = game.players[1].general.title

        try game.play(cardID: trick.id, targetID: 1)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }

        let visible = GameLogPresentation.visibleLines(from: game.log, players: game.players)
        let spoken = GameVoiceCue.spokenLines(from: game.log, players: game.players)
        XCTAssertTrue(visible.contains("你 对 \(targetName) 使用锦囊【顺手牵羊】。"), "\(visible)")
        XCTAssertTrue(visible.contains("你 从 \(targetName) 处获得【诸葛连弩】（顺手牵羊）。"), "\(visible)")
        XCTAssertTrue(spoken.contains("我对\(targetName)使用锦囊【顺手牵羊】。"), "\(spoken)")
        XCTAssertTrue(spoken.contains("我从\(targetName)处获得【诸葛连弩】（顺手牵羊）。"), "\(spoken)")
    }

    func testNullificationOpensSeatOrderedResponseWindowAndCancelsTrick() throws {
        var game = GameEngine.newGame(seed: 781, hands: [[.dismantle], [.nullification], [], [.peach]])
        try game.drawForTurn()
        let dismantle = try XCTUnwrap(game.human.hand.first { $0.kind == .dismantle })
        let targetName = game.players[3].name

        try game.play(cardID: dismantle.id, targetID: 3)

        XCTAssertEqual(game.phase, .respondingToTrick(responderID: 1))
        XCTAssertTrue(game.trickResponseSummary?.contains(game.players[3].general.title) == true)
        XCTAssertTrue(game.players[3].hand.contains { $0.kind == .peach })
        try game.respondToTrick(withNullification: true)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }

        XCTAssertTrue(game.players[3].hand.contains { $0.kind == .peach }, "Canceled dismantle must not remove the target card")
        XCTAssertTrue(game.log.contains { $0.contains("无懈可击") && $0.contains("过河拆桥") })
        XCTAssertEqual(game.phase, .action)
        XCTAssertTrue(game.log.contains { $0.contains(targetName) })
    }

    func testSecondNullificationCountersFirstAndAllowsTrickEffect() throws {
        var game = GameEngine.newGame(seed: 782, hands: [[.dismantle], [.nullification], [.nullification], [.peach]])
        try game.drawForTurn()
        let dismantle = try XCTUnwrap(game.human.hand.first { $0.kind == .dismantle })

        try game.play(cardID: dismantle.id, targetID: 3)
        try game.respondToTrick(withNullification: true)
        try game.respondToTrick(withNullification: true)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }

        XCTAssertFalse(game.players[3].hand.contains { $0.kind == .peach })
        XCTAssertTrue(game.log.contains { $0.contains("无懈可击") && $0.contains("反制") })
        XCTAssertTrue(game.log.contains { $0.contains(game.players[3].name) && $0.contains("过河拆桥") })
        XCTAssertEqual(game.phase, .action)
    }

    func testNullificationCannotBePlayedOutsideResponseWindow() throws {
        var game = GameEngine.newGame(seed: 783, hands: [[.nullification], [], [], []])
        try game.drawForTurn()
        let nullification = try XCTUnwrap(game.human.hand.first { $0.kind == .nullification })

        XCTAssertThrowsError(try game.play(cardID: nullification.id))
        XCTAssertEqual(game.phase, .action)
    }

    func testDuelAlternatesSlashResponsesUntilAPlayerFails() throws {
        var game = GameEngine.newGame(seed: 784, hands: [[.duel], [.slash], [], []], startingHP: [4, 4, 4, 4])
        try game.drawForTurn()
        let duel = try XCTUnwrap(game.human.hand.first { $0.kind == .duel })

        try game.play(cardID: duel.id, targetID: 1)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }

        XCTAssertEqual(game.phase, .awaitingDuelSlash(responderID: 1, challengerID: 0))
        XCTAssertTrue(game.advanceAI())
        XCTAssertEqual(game.phase, .awaitingDuelSlash(responderID: 0, challengerID: 1))
        try game.respondToDuel(withSlash: false)

        XCTAssertEqual(game.human.hp, 3)
        XCTAssertEqual(game.phase, .action)
        let visible = GameLogPresentation.visibleLines(from: game.log, players: game.players)
        XCTAssertTrue(visible.contains { $0.contains("你") && $0.contains("决斗") && $0.contains(game.players[1].general.title) }, "\(visible)")
    }

    func testHarvestChoiceIsAnnouncedWithTheCardName() {
        let event = "你 从五谷丰登中获得【杀】。"
        let player = Player(id: 0, name: "你", role: .lord, isHuman: true, general: .caoCao)

        XCTAssertEqual(GameVoiceCue.spokenLines(from: [event], players: [player]), ["我从五谷丰登中获得【杀】。"])
    }

    func testHistoryReplacesComputerSeatsWithTheirGeneralNames() {
        let players = [
            Player(id: 0, name: "你", role: .lord, isHuman: true, general: .caoCao),
            Player(id: 1, name: "电脑1", role: .rebel, isHuman: false, general: .luXun),
            Player(id: 2, name: "电脑2", role: .loyalist, isHuman: false, general: .guanYu),
            Player(id: 3, name: "电脑3", role: .spy, isHuman: false, general: .diaoChan)
        ]
        let events = ["电脑2 摸了2张牌。", "电脑3 对 电脑1 使用杀。", "轮到 电脑2。"]

        XCTAssertEqual(GameLogPresentation.visibleLines(from: events, players: players), [
            "关羽 摸了2张牌。", "貂蝉 对 陆逊 使用杀。", "轮到 关羽。"
        ])
    }

    func testStandardDeckCardsKeepTheirPrintedSuitAndRank() {
        let cards = StandardDeck.cards

        XCTAssertEqual(cards.count, 108)
        XCTAssertEqual(Set(cards.map(\.suit)), Set(Suit.allCases))
        XCTAssertEqual(cards.filter { $0.suit == .heart }.count, 27)
        XCTAssertEqual(cards.filter { $0.suit == .spade }.count, 27)
        XCTAssertEqual(cards.filter { $0.suit == .diamond }.count, 27)
        XCTAssertEqual(cards.filter { $0.suit == .club }.count, 27)
        XCTAssertTrue(cards.allSatisfy { (1...13).contains($0.rank) })
        XCTAssertEqual(cards.filter { $0.kind == .slash }.count, 30)
        XCTAssertEqual(cards.filter { $0.kind == .dodge }.count, 15)
        XCTAssertEqual(cards.filter { $0.kind == .peach }.count, 8)
    }

    func testEightTrigramsTreatsOnlyRedJudgmentCardsAsDodge() {
        XCTAssertTrue(GameEngine.eightTrigramsDodges(with: .heart))
        XCTAssertTrue(GameEngine.eightTrigramsDodges(with: .diamond))
        XCTAssertFalse(GameEngine.eightTrigramsDodges(with: .spade))
        XCTAssertFalse(GameEngine.eightTrigramsDodges(with: .club))
    }

    func testEveryCardHasAnExplanationForHoverHelp() {
        XCTAssertTrue(CardKind.allCases.allSatisfy { !$0.helpText.isEmpty })
        let tooltips = CardKind.allCases.map(\.tooltipText)
        XCTAssertEqual(Set(tooltips).count, CardKind.allCases.count)
        for card in CardKind.allCases {
            XCTAssertTrue(card.tooltipText.contains(card.title))
            XCTAssertTrue(card.tooltipText.contains(card.helpText))
        }
    }

    func testAmazingGraceTooltipMatchesItsImplementedDrawEffect() {
        XCTAssertEqual(CardKind.amazingGrace.helpText, "你摸两张牌。")
    }

    func testHarvestRevealsOneFaceUpCardPerLivingPlayerInSeatOrder() throws {
        var game = GameEngine.newGame(seed: 203, hands: [[.harvest], [], [], []])
        try game.drawForTurn()
        let harvest = try XCTUnwrap(game.human.hand.first { $0.kind == .harvest })

        try game.play(cardID: harvest.id)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }

        XCTAssertEqual(game.phase, .choosingHarvest(playerID: 0))
        XCTAssertEqual(game.harvestChoices.count, 4)
        XCTAssertEqual(game.players.map(\.hand.count), [2, 0, 0, 0])
        XCTAssertTrue(game.log.contains { $0.contains("五谷丰登亮出：") })
    }

    func testHarvestLetsEachPlayerChooseOneCardAndEndsAfterLastChoice() throws {
        var game = GameEngine.newGame(seed: 204, hands: [[.harvest], [], [], []])
        try game.drawForTurn()
        let harvest = try XCTUnwrap(game.human.hand.first { $0.kind == .harvest })
        try game.play(cardID: harvest.id)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }
        let firstChoice = try XCTUnwrap(game.harvestChoices.first)

        try game.chooseHarvest(cardID: firstChoice.id, by: 0)
        XCTAssertTrue(game.human.hand.contains(firstChoice))
        XCTAssertEqual(game.phase, .choosingHarvest(playerID: 1))

        while game.advanceAI() {}

        XCTAssertEqual(game.phase, .action)
        XCTAssertEqual(game.players.map(\.hand.count), [3, 1, 1, 1])
        XCTAssertTrue(game.discardPile.contains(harvest))
        XCTAssertTrue(game.harvestChoices.isEmpty)
    }

    func testHarvestRejectsCardsOutsideTheRevealedPool() throws {
        var game = GameEngine.newGame(seed: 205, hands: [[.harvest], [], [], []])
        try game.drawForTurn()
        let harvest = try XCTUnwrap(game.human.hand.first { $0.kind == .harvest })
        try game.play(cardID: harvest.id)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }
        let choices = game.harvestChoices

        XCTAssertThrowsError(try game.chooseHarvest(cardID: -1, by: 0))
        XCTAssertEqual(game.harvestChoices, choices)
        XCTAssertEqual(game.phase, .choosingHarvest(playerID: 0))
    }

    func testSpeechQueueAdvancesAfterEachUtteranceAndBecomesIdle() {
        var queue = SerialPlaybackQueue<String>()
        queue.enqueue(["装备贯石斧", "出杀"])

        XCTAssertEqual(queue.startNext(), "装备贯石斧")
        XCTAssertFalse(queue.isIdle)
        XCTAssertEqual(queue.finishCurrent(), "出杀")
        XCTAssertFalse(queue.isIdle)
        XCTAssertNil(queue.finishCurrent())
        XCTAssertTrue(queue.isIdle)
    }

    func testSpeechQueueIgnoresCompletionFromAnOlderUtterance() {
        var queue = SerialPlaybackQueue<String>()
        queue.enqueue(["旧语音"])
        XCTAssertEqual(queue.startNext(), "旧语音")
        queue.clear()
        queue.enqueue(["新语音"])
        XCTAssertEqual(queue.startNext(), "新语音")

        XCTAssertNil(queue.finishCurrent(matching: "旧语音"))
        XCTAssertEqual(queue.current, "新语音")
        XCTAssertEqual(queue.finishCurrent(matching: "新语音"), nil)
        XCTAssertTrue(queue.isIdle)
    }

    func testHumanSeatDeathDoesNotPretendTheLordDied() {
        var players = GameEngine.newGame(seed: 41, humanGeneral: .liuBei, humanRole: .loyalist).players
        players[0].isAlive = false

        XCTAssertNil(GameEngine.winner(for: players))
    }

    func testRandomIdentityAndGeneralUseTheWholeStandardRoster() {
        let games = (1...64).map { GameEngine.newGame(seed: UInt64($0), humanGeneral: nil, humanRole: nil, generalPool: General.allCases) }
        let roles = Set(games.map { $0.human.role })
        let generals = Set(games.flatMap { $0.players.map(\.general) })

        XCTAssertEqual(roles, Set(Role.allCases))
        XCTAssertEqual(generals, Set(General.allCases))
        XCTAssertEqual(General.allCases.count, 25)
        for game in games {
            XCTAssertEqual(Set(game.players.map(\.role)), Set(Role.allCases))
            XCTAssertEqual(Set(game.players.map(\.general)).count, game.players.count)
        }
    }

    func testEveryStandardGeneralHasAVisibleSkillSummary() {
        XCTAssertEqual(Set(General.allCases.map(\.title)).count, General.allCases.count)
        XCTAssertTrue(General.allCases.allSatisfy { !$0.skillSummary.isEmpty })
        XCTAssertTrue(General.allCases.allSatisfy { $0.skill.contains($0.skillSummary.components(separatedBy: "：")[0]) })
    }

    func testFourPlayerGameDealsFourCardsAndStartsWithLord() {
        let game = GameEngine.newGame(seed: 7)

        XCTAssertEqual(game.players.count, 4)
        XCTAssertEqual(game.players.filter { $0.role == .lord }.count, 1)
        XCTAssertEqual(game.players.filter { $0.role == .loyalist }.count, 1)
        XCTAssertEqual(game.players.filter { $0.role == .rebel }.count, 1)
        XCTAssertEqual(game.players.filter { $0.role == .spy }.count, 1)
        XCTAssertTrue(game.players[0].isHuman)
        XCTAssertEqual(game.players.map(\.hand.count), [4, 4, 4, 4])
        XCTAssertEqual(game.currentPlayerID, 0)
        XCTAssertEqual(game.phase, .drawing)
    }

    func testDrawingPhaseDrawsTwoCardsAndBeginsActionPhase() throws {
        var game = GameEngine.newGame(seed: 7)

        try game.drawForTurn()

        XCTAssertEqual(game.players[0].hand.count, 6)
        XCTAssertEqual(game.phase, .action)
    }

    func testRecentActivityShowsTheLatestThreeLogEntriesInOrder() throws {
        var game = GameEngine.newGame(seed: 7)
        try game.drawForTurn()
        try game.endTurn()

        XCTAssertEqual(game.recentActivity, Array(game.log.suffix(3)))
        XCTAssertEqual(game.recentActivity.count, 3)
    }

    func testSlashCanOnlyBeUsedOncePerTurnAndDodgePreventsDamage() throws {
        var game = GameEngine.newGame(seed: 7, hands: [
            [.slash, .slash], [.dodge], [], []
        ])
        try game.drawForTurn()
        let targetHP = game.players[1].hp
        let slash = try XCTUnwrap(game.players[0].hand.first { $0.kind == .slash })

        try game.play(cardID: slash.id, targetID: 1)

        XCTAssertEqual(game.phase, .action)
        XCTAssertEqual(game.players[1].hp, targetHP)
        let secondSlash = try XCTUnwrap(game.players[0].hand.first { $0.kind == .slash })
        XCTAssertThrowsError(try game.play(cardID: secondSlash.id, targetID: 1))
    }

    func testUnansweredSlashDealsDamageAndPeachRestoresHealth() throws {
        var game = GameEngine.newGame(seed: 7, hands: [
            [.slash, .peach], [], [], []
        ], startingHP: [3, 4, 4, 4])
        try game.drawForTurn()
        let slash = try XCTUnwrap(game.players[0].hand.first { $0.kind == .slash })
        try game.play(cardID: slash.id, targetID: 3)
        XCTAssertEqual(game.players[3].hp, 3)
        XCTAssertTrue(game.log.contains { $0 == "你 使用【杀】对 电脑3 造成 1 点伤害。" }, "\(game.log)")

        let peach = try XCTUnwrap(game.players[0].hand.first { $0.kind == .peach })
        try game.play(cardID: peach.id, targetID: 0)
        XCTAssertEqual(game.players[0].hp, 4)
    }

    func testHumanCanDodgeAnAISlashAndTheTurnContinues() throws {
        var game = GameEngine.newGame(seed: 7, hands: [
            [.dodge], [.slash], [.slash], [.slash]
        ], humanRole: .rebel)
        try game.drawForTurn()
        try game.endTurn()
        game.playAITurns()
        while case let .respondingToTrick(responderID) = game.phase {
            if responderID == 0 { try game.respondToTrick(withNullification: false) }
            else if !game.advanceAI() { break }
            game.playAITurns()
        }

        guard case .awaitingDodge(targetID: 0, _) = game.phase else { return XCTFail("Expected the AI to attack the human") }
        try game.respondToSlash(withDodge: true)
        game.continueAfterHumanResponse()

        XCTAssertEqual(game.players[0].hp, game.players[0].maxHP, "\(game.log)")
        XCTAssertEqual(game.currentPlayerID, 1, "\(game.log)")
        XCTAssertEqual(game.phase, .action)
    }

    func testHumanEightTrigramsRevealsTheJudgmentCardAndExplainsTheResult() throws {
        let prepared = try XCTUnwrap((1...1_000).compactMap { seed -> GameEngine? in
            var candidate = GameEngine.newGame(seed: UInt64(seed), hands: [
                [.eightTrigrams], [.slash], [.slash], [.slash]
            ], humanGeneral: .guanYu, humanRole: .rebel)
            try? candidate.drawForTurn()
            guard !candidate.human.hand.contains(where: { $0.kind == .dodge }),
                  let armor = candidate.human.hand.first(where: { $0.kind == .eightTrigrams }) else { return nil }
            try? candidate.play(cardID: armor.id)
            try? candidate.endTurn()
            candidate.playAITurns()
            if case .awaitingDodge(targetID: 0, _) = candidate.phase { return candidate }
            return nil
        }.first)
        var game = prepared
        guard case .awaitingDodge(targetID: 0, let attackerID) = game.phase else { return XCTFail("Expected an AI attack") }
        try game.respondToSlash(withDodge: true)

        let judgment = try XCTUnwrap(game.discardPile.last)
        let event = try XCTUnwrap(game.log.first { $0.contains("发动八卦阵：翻出") }, "\(game.log)")
        XCTAssertTrue(event.contains(judgment.judgmentDescription))
        XCTAssertTrue(event.contains("\(game.players[attackerID].name) 对 你 使用的【杀】"))
        XCTAssertEqual(event.contains("红色，视为使用【闪】"), judgment.suit.isRed)
        XCTAssertEqual(event.contains("黑色，判定失败"), !judgment.suit.isRed)
        XCTAssertTrue(game.discardPile.contains(judgment))
    }

    func testHumanCanSaveThemselfFromDyingWithPeach() throws {
        let hands: [[CardKind]] = [[.peach], [.slash], [.slash], [.slash]]
        let seed = try XCTUnwrap((1...10000).map(UInt64.init).first { seed in
            var candidate = GameEngine.newGame(seed: seed, hands: hands, startingHP: [1, 4, 4, 4])
            try? candidate.drawForTurn()
            try? candidate.endTurn()
            candidate.playAITurns()
            guard case .dying(targetID: 0, responderID: 0) = candidate.phase else { return false }
            return candidate.human.hand.contains { $0.kind == .peach }
        })
        var game = GameEngine.newGame(seed: seed, hands: hands, startingHP: [1, 4, 4, 4])
        try game.drawForTurn()
        try game.endTurn()
        game.playAITurns()

        XCTAssertEqual(game.phase, .dying(targetID: 0, responderID: 0), "\(game.log) hp=\(game.players[0].hp)")
        try game.respondToDying(withPeach: true)
        XCTAssertEqual(game.players[0].hp, 1)
        XCTAssertTrue(game.players[0].isAlive)
        game.continueAfterHumanResponse()
    }

    func testWinningConditionsRespectIdentityObjectives() {
        var players = GameEngine.newGame(seed: 7).players
        for index in players.indices where players[index].role != .lord {
            players[index].isAlive = false
        }

        XCTAssertEqual(GameEngine.winner(for: players), .lordAndLoyalist)
        players[0].isAlive = false
        XCTAssertEqual(GameEngine.winner(for: players), .rebels)
    }

    func testSpyWinsOnlyWhenTheLordFallsAsTheLastOtherSurvivor() {
        var players = GameEngine.newGame(seed: 7).players
        for index in players.indices where players[index].role != .spy {
            players[index].isAlive = false
        }

        XCTAssertEqual(GameEngine.winner(for: players), .spy)
        players[0].isAlive = true
        XCTAssertNil(GameEngine.winner(for: players))
    }

    func testStandardDeckContainsAll108CardsAndExpectedCategories() {
        let game = GameEngine.newGame(seed: 19)

        XCTAssertEqual(game.drawPile.count + game.players.reduce(0) { $0 + $1.hand.count }, 108)
        XCTAssertEqual(game.cardCounts[.basic], 53)
        XCTAssertEqual(game.cardCounts[.trick], 36)
        XCTAssertEqual(game.cardCounts[.equipment], 19)
        XCTAssertTrue(game.allCards.contains { $0.title == "无懈可击" })
        XCTAssertTrue(game.allCards.contains { $0.title == "诸葛连弩" })
        XCTAssertTrue(game.allCards.contains { $0.title == "寒冰剑" })
    }

    func testEveryStandardCardKindMapsToItsOwnCardIllustration() {
        let illustrationIndexes = CardKind.allCases.map(\.illustrationIndex)

        XCTAssertEqual(illustrationIndexes.count, 29)
        XCTAssertEqual(Set(illustrationIndexes).count, illustrationIndexes.count)
        XCTAssertEqual(Set(illustrationIndexes), Set(0..<29))
    }

    func testAIAdvancesOneVisibleStepAtATime() throws {
        var game = GameEngine.newGame(seed: 7, hands: [[], [.slash], [], []])
        try game.drawForTurn()
        try game.endTurn()

        let previousLogCount = game.log.count
        let advanced = game.advanceAI()

        XCTAssertTrue(advanced)
        XCTAssertEqual(game.currentPlayerID, 1)
        XCTAssertEqual(game.phase, .action)
        XCTAssertGreaterThan(game.log.count, previousLogCount)
    }

    func testEquipmentCardsEnterEquipmentAreaInsteadOfHandLimit() throws {
        var game = GameEngine.newGame(seed: 7, hands: [[.crossbow], [], [], []])
        try game.drawForTurn()
        let weapon = try XCTUnwrap(game.human.hand.first { $0.category == .equipment })

        try game.play(cardID: weapon.id)

        XCTAssertEqual(game.human.equipment.values.map(\.title), [weapon.title])
        XCTAssertFalse(game.human.hand.contains(where: { $0.id == weapon.id }))
    }

    func testReplacingEquipmentMovesTheOldCardToDiscardOnce() throws {
        var game = GameEngine.newGame(seed: 785, hands: [[.crossbow, .axe], [], [], []])
        try game.drawForTurn()
        let crossbow = try XCTUnwrap(game.human.hand.first { $0.kind == .crossbow })
        let axe = try XCTUnwrap(game.human.hand.first { $0.kind == .axe })

        try game.play(cardID: crossbow.id)
        try game.play(cardID: axe.id)

        XCTAssertEqual(game.discardPile.filter { $0.id == crossbow.id }.count, 1)
        XCTAssertEqual(game.human.equipment[.weapon]?.id, axe.id)
    }

    func testWeaponChangesAttackRangeAndTrickProducesVisibleAction() throws {
        var game = GameEngine.newGame(seed: 7, hands: [[.kylinBow, .amazingGrace], [], [], []])
        try game.drawForTurn()
        let bow = try XCTUnwrap(game.human.hand.first { $0.kind == .kylinBow })
        try game.play(cardID: bow.id)
        XCTAssertTrue(game.isLegalTarget(2, from: 0))

        let before = game.human.hand.count
        let trick = try XCTUnwrap(game.human.hand.first { $0.kind == .amazingGrace })
        try game.play(cardID: trick.id)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }
        XCTAssertEqual(game.human.hand.count, before + 1)
        XCTAssertTrue(game.log.contains { $0.contains("无中生有") })
    }

    func testBarbarianInvasionAndArrowsRequireTheirCorrectResponses() throws {
        var barbarian = GameEngine.newGame(seed: 7, hands: [[.barbarianInvasion], [.slash], [], []])
        try barbarian.drawForTurn()
        let invasion = try XCTUnwrap(barbarian.human.hand.first { $0.kind == .barbarianInvasion })
        try barbarian.play(cardID: invasion.id)
        for _ in 0..<4 { try barbarian.respondToTrick(withNullification: false) }
        XCTAssertFalse(barbarian.players[1].hand.contains { $0.kind == .slash })
        XCTAssertTrue(barbarian.log.contains { $0.contains("响应【南蛮入侵】") })

        var arrows = GameEngine.newGame(seed: 7, hands: [[.arrows], [.dodge], [], []])
        try arrows.drawForTurn()
        let volley = try XCTUnwrap(arrows.human.hand.first { $0.kind == .arrows })
        try arrows.play(cardID: volley.id)
        for _ in 0..<4 { try arrows.respondToTrick(withNullification: false) }
        XCTAssertFalse(arrows.players[1].hand.contains { $0.kind == .dodge })
        XCTAssertTrue(arrows.log.contains { $0.contains("响应【万箭齐发】") })
    }

    func testSelectableGeneralsApplySlashSkills() throws {
        let noFeedbackOrEmptyHandImmunity = General.allCases.filter { $0 != .simaYi && $0 != .zhugeLiang }
        var zhangFei = GameEngine.newGame(seed: 7, hands: [[.slash, .slash], [], [], []], humanGeneral: .zhangFei, generalPool: noFeedbackOrEmptyHandImmunity)
        try zhangFei.drawForTurn()
        let first = try XCTUnwrap(zhangFei.human.hand.first { $0.kind == .slash })
        try zhangFei.play(cardID: first.id, targetID: 1)
        let second = try XCTUnwrap(zhangFei.human.hand.first { $0.kind == .slash })
        try zhangFei.play(cardID: second.id, targetID: 3)
        XCTAssertEqual(zhangFei.log.filter { $0.contains("使用杀") }.count, 2)

        var zhaoYun = GameEngine.newGame(seed: 7, hands: [[.dodge], [], [], []], humanGeneral: .zhaoYun)
        try zhaoYun.drawForTurn()
        let convertedSlash = try XCTUnwrap(zhaoYun.human.hand.first { $0.kind == .dodge })
        try zhaoYun.play(cardID: convertedSlash.id, targetID: 1)
        XCTAssertTrue(zhaoYun.log.contains { $0.contains("使用杀") })
    }

    func testIndulgenceDelaysAndSkipsTheTargetActionPhase() throws {
        var game = GameEngine.newGame(seed: 7, hands: [[.indulgence], [], [], []])
        try game.drawForTurn()
        let card = try XCTUnwrap(game.human.hand.first { $0.kind == .indulgence })
        try game.play(cardID: card.id, targetID: 1)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }
        XCTAssertEqual(game.players[1].delayedTricks.map(\.kind), [.indulgence])

        try game.endTurn()
        XCTAssertTrue(game.advanceAI())

        XCTAssertTrue(game.players[1].delayedTricks.isEmpty)
        XCTAssertTrue(game.log.contains { $0.contains("跳过出牌阶段") })
        XCTAssertEqual(game.currentPlayerID, 2)
    }

    func testDuelConsumesTheTargetSlashAndWaitsForChallengersResponse() throws {
        var game = GameEngine.newGame(seed: 7, hands: [[.duel], [.slash], [], []])
        try game.drawForTurn()
        let duel = try XCTUnwrap(game.human.hand.first { $0.kind == .duel })
        try game.play(cardID: duel.id, targetID: 1)
        for _ in 0..<4 { try game.respondToTrick(withNullification: false) }
        XCTAssertTrue(game.players[1].hand.contains { $0.kind == .slash })
        XCTAssertTrue(game.advanceAI())

        XCTAssertFalse(game.players[1].hand.contains { $0.kind == .slash })
        XCTAssertEqual(game.human.hp, game.human.maxHP)
        XCTAssertEqual(game.phase, .awaitingDuelSlash(responderID: 0, challengerID: 1))
        XCTAssertTrue(game.log.contains { $0.contains("决斗") })
    }
}
