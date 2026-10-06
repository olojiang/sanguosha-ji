import Foundation

public enum Role: String, CaseIterable, Equatable {
    case lord, loyalist, rebel, spy

    public var title: String {
        switch self {
        case .lord: "主公"
        case .loyalist: "忠臣"
        case .rebel: "反贼"
        case .spy: "内奸"
        }
    }
}

public enum CardCategory: String, CaseIterable, Equatable {
    case basic, trick, equipment
    public var title: String {
        switch self { case .basic: "基本牌"; case .trick: "锦囊"; case .equipment: "装备" }
    }
}

public enum CardKind: String, CaseIterable, Equatable, Sendable {
    case slash, dodge, peach, wine
    case lightning, indulgence, barbarianInvasion, arrows, harvest, godSalvation
    case nullification, snatch, dismantle, duel, collateral, amazingGrace
    case offensiveHorse, defensiveHorse, eightTrigrams, blackShield
    case doubleSword, iceSword, greenDragonBlade, QinggangSword, serpentSpear
    case kylinBow, crossbow, axe, halberd

    public var illustrationIndex: Int {
        switch self {
        case .slash: 0
        case .dodge: 1
        case .peach: 2
        case .wine: 3
        case .lightning: 4
        case .indulgence: 5
        case .barbarianInvasion: 6
        case .arrows: 7
        case .harvest: 8
        case .godSalvation: 9
        case .nullification: 10
        case .snatch: 11
        case .dismantle: 12
        case .duel: 13
        case .collateral: 14
        case .amazingGrace: 15
        case .offensiveHorse: 16
        case .defensiveHorse: 17
        case .eightTrigrams: 18
        case .blackShield: 19
        case .doubleSword: 20
        case .iceSword: 21
        case .greenDragonBlade: 22
        case .QinggangSword: 23
        case .serpentSpear: 24
        case .kylinBow: 25
        case .crossbow: 26
        case .axe: 27
        case .halberd: 28
        }
    }

    public var title: String {
        switch self {
        case .slash: "杀"
        case .dodge: "闪"
        case .peach: "桃"
        case .wine: "酒"
        case .lightning: "闪电"
        case .indulgence: "乐不思蜀"
        case .barbarianInvasion: "南蛮入侵"
        case .arrows: "万箭齐发"
        case .harvest: "五谷丰登"
        case .godSalvation: "桃园结义"
        case .nullification: "无懈可击"
        case .snatch: "顺手牵羊"
        case .dismantle: "过河拆桥"
        case .duel: "决斗"
        case .collateral: "借刀杀人"
        case .amazingGrace: "无中生有"
        case .offensiveHorse: "进攻马"
        case .defensiveHorse: "防御马"
        case .eightTrigrams: "八卦阵"
        case .blackShield: "仁王盾"
        case .doubleSword: "雌雄双股剑"
        case .iceSword: "寒冰剑"
        case .greenDragonBlade: "青龙偃月刀"
        case .QinggangSword: "青釭剑"
        case .serpentSpear: "丈八蛇矛"
        case .kylinBow: "麒麟弓"
        case .crossbow: "诸葛连弩"
        case .axe: "贯石斧"
        case .halberd: "方天画戟"
        }
    }

    public var category: CardCategory {
        switch self {
        case .slash, .dodge, .peach, .wine: .basic
        case .lightning, .indulgence, .barbarianInvasion, .arrows, .harvest, .godSalvation,
             .nullification, .snatch, .dismantle, .duel, .collateral, .amazingGrace: .trick
        default: .equipment
        }
    }

    public var helpText: String {
        switch self {
        case .slash: "对攻击范围内的角色使用；若其没有闪，造成 1 点伤害。"
        case .dodge: "受到杀时打出，抵消这次杀。"
        case .peach: "出牌阶段回复自己 1 点体力；角色濒死时也可用于救援。"
        case .wine: "本回合下一张杀额外造成 1 点伤害。"
        case .lightning: "放入自己的判定区；下回合开始时结算，本版本简化为 1 点伤害。"
        case .indulgence: "指定一名角色放入其判定区；当前版本尚未翻判定牌，暂按跳过出牌阶段结算。"
        case .barbarianInvasion: "其他角色依次打出杀响应，否则受到 1 点伤害。"
        case .arrows: "其他角色依次打出闪响应，否则受到 1 点伤害。"
        case .harvest: "亮出等同存活角色数的牌；从使用者开始，按座次依次选择并获得一张。"
        case .godSalvation: "所有受伤角色各回复 1 点体力。"
        case .nullification: "响应锦囊：抵消当前锦囊；其他角色可再用无懈可击反制。全部连续放弃后，按奇偶决定锦囊是否生效。"
        case .snatch: "获得距离 1 内一名角色的一张手牌或装备。"
        case .dismantle: "弃置一名角色的一张手牌或装备。"
        case .duel: "与一名角色决斗；从目标开始轮流打出【杀】，先无法响应者受到 1 点伤害。"
        case .collateral: "指定一名装备武器的角色；借刀结算目前仍简化。"
        case .amazingGrace: "当前简化为摸两张牌；标准规则应亮出牌堆顶牌并由存活角色依次选择。"
        case .offensiveHorse: "进攻马：你计算与其他角色的距离 -1。"
        case .defensiveHorse: "防御马：其他角色计算与你的距离 +1。"
        case .eightTrigrams: "需要使用闪时发动：翻开牌堆顶一张牌。红色视为使用闪并抵消攻击；黑色判定失败，受到攻击伤害。判定牌进入弃牌堆。"
        case .blackShield: "防具；当前规则未实现其颜色免疫效果。"
        case .doubleSword: "雌雄双股剑：攻击范围 2。"
        case .iceSword: "武器，攻击范围 2；弃牌特效尚未实现。"
        case .greenDragonBlade: "武器，攻击范围 3。"
        case .QinggangSword: "青釭剑：攻击范围 2；无视目标防具效果尚未实现。"
        case .serpentSpear: "武器，攻击范围 3。"
        case .kylinBow: "武器，攻击范围 5。"
        case .crossbow: "武器，攻击范围 1；允许连续使用杀。"
        case .axe: "武器，攻击范围 3；强制命中特效尚未实现。"
        case .halberd: "武器，攻击范围 4。"
        }
    }

    public var tooltipText: String { "\(title) · \(category.title)\n\(helpText)" }

    public var equipmentSlot: EquipmentSlot? {
        switch self {
        case .offensiveHorse: .offensiveHorse
        case .defensiveHorse: .defensiveHorse
        case .eightTrigrams, .blackShield: .armor
        case .slash, .dodge, .peach, .wine, .lightning, .indulgence, .barbarianInvasion,
             .arrows, .harvest, .godSalvation, .nullification, .snatch, .dismantle,
             .duel, .collateral, .amazingGrace: nil
        default: .weapon
        }
    }
}

public enum EquipmentSlot: String, CaseIterable, Equatable { case weapon, armor, offensiveHorse, defensiveHorse }

public enum Suit: String, CaseIterable, Equatable, Sendable {
    case spade, heart, club, diamond

    public var title: String {
        switch self {
        case .spade: "黑桃"
        case .heart: "红桃"
        case .club: "梅花"
        case .diamond: "方块"
        }
    }

    public var isRed: Bool { self == .heart || self == .diamond }
}

public enum General: String, CaseIterable, Equatable {
    case caoCao, simaYi, xiahouDun, zhangLiao, xuChu, guoJia, zhenJi
    case liuBei, guanYu, zhangFei, zhugeLiang, zhaoYun, maChao, huangYueYing
    case sunQuan, ganNing, lvMeng, huangGai, zhouYu, daQiao, luXun, sunShangXiang
    case huaTuo, lvBu, diaoChan

    public var title: String {
        switch self {
        case .caoCao: "曹操"
        case .simaYi: "司马懿"
        case .xiahouDun: "夏侯惇"
        case .zhangLiao: "张辽"
        case .xuChu: "许褚"
        case .guoJia: "郭嘉"
        case .zhenJi: "甄姬"
        case .liuBei: "刘备"
        case .guanYu: "关羽"
        case .zhangFei: "张飞"
        case .zhugeLiang: "诸葛亮"
        case .zhaoYun: "赵云"
        case .maChao: "马超"
        case .huangYueYing: "黄月英"
        case .sunQuan: "孙权"
        case .ganNing: "甘宁"
        case .lvMeng: "吕蒙"
        case .huangGai: "黄盖"
        case .zhouYu: "周瑜"
        case .daQiao: "大乔"
        case .luXun: "陆逊"
        case .sunShangXiang: "孙尚香"
        case .huaTuo: "华佗"
        case .lvBu: "吕布"
        case .diaoChan: "貂蝉"
        }
    }

    public var skill: String {
        switch self {
        case .caoCao: "奸雄：受到伤害后可获得造成伤害的牌；主公技护驾可求魏势力角色打闪。"
        case .simaYi: "反馈：受到伤害后获得伤害来源一张牌；鬼才可替换判定牌。"
        case .xiahouDun: "刚烈：受到伤害后判定，非红桃时可令伤害来源弃牌或受伤。"
        case .zhangLiao: "突袭：摸牌阶段可少摸牌，改为获得其他角色的手牌。"
        case .xuChu: "裸衣：摸牌阶段少摸一张，本回合杀和决斗伤害增加。"
        case .guoJia: "天妒：获得自己的判定牌；遗计：受到伤害后摸两张并分配。"
        case .zhenJi: "倾国：黑色牌可当闪；洛神：回合开始时反复判定并收取黑色牌。"
        case .liuBei: "仁德：可分发手牌；激将：主公技，可请求蜀势力角色出杀。"
        case .guanYu: "武圣：红色牌可当杀使用。"
        case .zhangFei: "咆哮：出牌阶段使用杀没有次数限制。"
        case .zhugeLiang: "观星：回合开始时调整牌堆顶；空城：空手牌时不能成为杀或决斗目标。"
        case .zhaoYun: "龙胆：可将杀当闪、闪当杀使用。"
        case .maChao: "马术：计算与其他角色的距离 -1；铁骑：杀可能令目标无法出闪。"
        case .huangYueYing: "集智：使用普通锦囊后摸一张；奇才：使用锦囊无距离限制。"
        case .sunQuan: "制衡：出牌阶段弃牌并摸等量牌；主公技救援可强化吴势力角色的桃。"
        case .ganNing: "奇袭：黑色手牌可当过河拆桥。"
        case .lvMeng: "克己：本回合未使用杀时，可跳过弃牌。"
        case .huangGai: "苦肉：失去 1 点体力并摸两张牌。"
        case .zhouYu: "英姿：摸牌阶段多摸一张；反间：展示一张牌并由对方选择。"
        case .daQiao: "国色：方块牌可当乐不思蜀；流离：可将杀转移给其他角色。"
        case .luXun: "谦逊：不受顺手牵羊影响；连营：失去最后一张手牌后摸一张。"
        case .sunShangXiang: "结姻：弃两张牌令一名受伤男性回复；枭姬：失去装备后摸两张。"
        case .huaTuo: "急救：回合外红色牌可当桃；青囊：弃一张牌令角色回复体力。"
        case .lvBu: "无双：杀需两张闪响应；决斗需连续打出两张杀。"
        case .diaoChan: "离间：弃一张牌令两名男性决斗；闭月：结束阶段摸一张牌。"
        }
    }

    public var skillSummary: String {
        switch self {
        case .caoCao: "奸雄：伤害后拿牌"
        case .simaYi: "反馈：受伤后获得来源牌"
        case .xiahouDun: "刚烈：判定后反击"
        case .zhangLiao: "突袭：改为拿取手牌"
        case .xuChu: "裸衣：杀与决斗伤害+1"
        case .guoJia: "遗计：受伤后摸牌并分配"
        case .zhenJi: "倾国：黑牌当闪 · 洛神判定摸牌"
        case .liuBei: "仁德：可分发手牌"
        case .guanYu: "武圣：红牌当杀"
        case .zhangFei: "咆哮：杀无次数限制"
        case .zhugeLiang: "空城：空手牌时免受杀与决斗"
        case .zhaoYun: "龙胆：杀闪互换"
        case .maChao: "马术：与他人距离-1"
        case .huangYueYing: "集智：使用锦囊后摸牌"
        case .sunQuan: "制衡：弃牌后摸等量牌"
        case .ganNing: "奇袭：黑牌当过河拆桥"
        case .lvMeng: "克己：未出杀可免弃牌"
        case .huangGai: "苦肉：失去体力摸两张"
        case .zhouYu: "英姿：摸牌阶段多摸一张"
        case .daQiao: "国色：方块当乐不思蜀"
        case .luXun: "连营：失去最后手牌后摸牌"
        case .sunShangXiang: "枭姬：失去装备后摸两张"
        case .huaTuo: "急救：回合外红牌当桃"
        case .lvBu: "无双：杀需两张闪响应"
        case .diaoChan: "闭月：结束阶段摸牌"
        }
    }

    public var maxHP: Int {
        switch self {
        case .simaYi, .guoJia, .zhenJi, .zhugeLiang, .huangYueYing,
             .zhouYu, .daQiao, .luXun, .sunShangXiang, .huaTuo, .diaoChan: 3
        default: 4
        }
    }
}

public struct Card: Identifiable, Equatable, Sendable {
    public let id: Int
    public let kind: CardKind
    public let suit: Suit
    public let rank: Int

    public var title: String { kind.title }
    public var category: CardCategory { kind.category }
    public var rankTitle: String { ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][rank - 1] }
    public var judgmentDescription: String { "【\(suit.title)\(rankTitle)·\(title)】" }

    public init(id: Int, kind: CardKind, suit: Suit = .spade, rank: Int = 1) {
        self.id = id
        self.kind = kind
        self.suit = suit
        self.rank = rank
    }
}

public struct Player: Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let role: Role
    public let isHuman: Bool
    public let general: General
    public var hp = 4
    public var hand: [Card] = []
    public var equipment: [EquipmentSlot: Card] = [:]
    public var delayedTricks: [Card] = []
    public var isAlive = true

    public var maxHP: Int { general.maxHP + (role == .lord ? 1 : 0) }
    public var healthStatus: String { "\(hp)/\(maxHP)" }
}

public enum GamePhase: Equatable {
    case drawing
    case action
    case choosingHarvest(playerID: Int)
    case awaitingDodge(targetID: Int, attackerID: Int)
    case awaitingDuelSlash(responderID: Int, challengerID: Int)
    case respondingToTrick(responderID: Int)
    case dying(targetID: Int, responderID: Int)
    case gameOver
}

public enum WinningSide: Equatable {
    case lordAndLoyalist
    case rebels
    case spy
}

public enum GameError: Error, Equatable {
    case wrongPhase
    case missingCard
    case invalidTarget
    case outOfRange
    case slashAlreadyUsed
    case invalidCard
}

enum StandardDeck {
    static let cards: [Card] = {
        typealias RankCards = (Int, [CardKind])
        let suits: [(Suit, [RankCards])] = [
            (.heart, [
                (1, [.godSalvation, .arrows]), (2, [.dodge, .dodge]), (3, [.peach, .harvest]),
                (4, [.peach, .harvest]), (5, [.kylinBow, .offensiveHorse]), (6, [.peach, .indulgence]),
                (7, [.peach, .amazingGrace]), (8, [.peach, .amazingGrace]), (9, [.peach, .amazingGrace]),
                (10, [.slash, .slash]), (11, [.slash, .amazingGrace]), (12, [.peach, .dismantle, .lightning]),
                (13, [.dodge, .defensiveHorse])
            ]),
            (.spade, [
                (1, [.duel, .lightning]), (2, [.doubleSword, .eightTrigrams, .iceSword]),
                (3, [.dismantle, .snatch]), (4, [.dismantle, .snatch]), (5, [.greenDragonBlade, .offensiveHorse]),
                (6, [.indulgence, .QinggangSword]), (7, [.slash, .barbarianInvasion]),
                (8, [.slash, .slash]), (9, [.slash, .slash]), (10, [.slash, .slash]),
                (11, [.snatch, .nullification]), (12, [.dismantle, .serpentSpear]),
                (13, [.barbarianInvasion, .defensiveHorse])
            ]),
            (.diamond, [
                (1, [.crossbow, .duel]), (2, [.dodge, .dodge]), (3, [.dodge, .snatch]),
                (4, [.dodge, .snatch]), (5, [.dodge, .axe]), (6, [.slash, .dodge]),
                (7, [.slash, .dodge]), (8, [.slash, .dodge]), (9, [.slash, .dodge]),
                (10, [.slash, .dodge]), (11, [.dodge, .dodge]),
                (12, [.peach, .halberd, .nullification]), (13, [.slash, .offensiveHorse])
            ]),
            (.club, [
                (1, [.duel, .crossbow]), (2, [.slash, .eightTrigrams, .blackShield]),
                (3, [.slash, .dismantle]), (4, [.slash, .dismantle]), (5, [.slash, .defensiveHorse]),
                (6, [.slash, .indulgence]), (7, [.slash, .barbarianInvasion]),
                (8, [.slash, .slash]), (9, [.slash, .slash]), (10, [.slash, .slash]),
                (11, [.slash, .slash]), (12, [.collateral, .nullification]), (13, [.collateral, .nullification])
            ])
        ]
        return suits.flatMap { suit, ranks in
            ranks.flatMap { rank, kinds in kinds.map { Card(id: 0, kind: $0, suit: suit, rank: rank) } }
        }.enumerated().map { Card(id: $0.offset, kind: $0.element.kind, suit: $0.element.suit, rank: $0.element.rank) }
    }()
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}
