import Foundation

public struct GeneralGuide: Equatable, Sendable {
    public let general: General
    public let faction: String
    public let strategy: String
    public let openingTip: String
    public let newPlayerTip: String
    public let implementationNote: String

    public var id: General { general }

    private init(
        _ general: General,
        faction: String,
        strategy: String,
        openingTip: String,
        newPlayerTip: String,
        implementationNote: String
    ) {
        self.general = general
        self.faction = faction
        self.strategy = strategy
        self.openingTip = openingTip
        self.newPlayerTip = newPlayerTip
        self.implementationNote = implementationNote
    }

    public static let all: [GeneralGuide] = [
        .init(
            .caoCao,
            faction: "魏",
            strategy: "曹操体力较厚，适合站在前排观察局势。受到伤害后留意造成伤害的牌，受伤有时能转成资源。",
            openingTip: "先留闪和桃保命；手牌里有装备或关键锦囊时，再考虑承担伤害。",
            newPlayerTip: "不要为了触发奸雄主动挨打。主公身份时先辨认威胁，再决定是否公开保护队友。",
            implementationNote: "奸雄目前按简化方式取弃牌堆顶牌；护驾尚未接入。"
        ),
        .init(
            .simaYi,
            faction: "魏",
            strategy: "司马懿受到伤害后可以借反馈削弱伤害来源。更适合与关键敌人保持互动，而非盲目集火。",
            openingTip: "记住谁造成了伤害；反馈会优先从其手牌中取牌。",
            newPlayerTip: "保留防御牌，把反馈当作受伤后的补偿，不要为了拿牌故意掉血。",
            implementationNote: "反馈目前只会获得来源的一张手牌；鬼才改判尚未接入。"
        ),
        .init(
            .xiahouDun,
            faction: "魏",
            strategy: "刚烈能让攻击者为伤害付出代价，适合让对手重新评估是否攻击你。",
            openingTip: "留住闪与桃。受伤后看判定结果，再决定反击方向。",
            newPlayerTip: "当前版本不会自动触发刚烈，暂时按普通四血武将使用。",
            implementationNote: "刚烈尚未接入。"
        ),
        .init(
            .zhangLiao,
            faction: "魏",
            strategy: "突袭擅长在摸牌阶段压低敌人的选择，同时补充自己的手牌。优先针对手牌多、关键牌可能较多的对手。",
            openingTip: "摸牌前观察其他角色的手牌数量；规则允许时优先拿取最危险目标的牌。",
            newPlayerTip: "突袭尚未接入，当前先使用常规摸牌流程；注意留闪和桃。",
            implementationNote: "突袭尚未接入。"
        ),
        .init(
            .xuChu,
            faction: "魏",
            strategy: "裸衣通过少摸牌换取更强的杀与决斗，适合手里已有进攻牌时主动压制。",
            openingTip: "开局先检查手牌是否有杀或决斗；没有进攻牌时不要急着裸衣。",
            newPlayerTip: "当前只实现少摸一张，杀与决斗加伤未实现；先把他当作摸牌较少的武将。",
            implementationNote: "少摸一张已实现；裸衣增伤尚未接入。"
        ),
        .init(
            .guoJia,
            faction: "魏",
            strategy: "郭嘉可以把受伤转化为补牌，再把关键牌分给队友。适合保护团队核心并灵活调配手牌。",
            openingTip: "队友缺闪、桃或关键锦囊时优先补给；避免把全部牌留给自己。",
            newPlayerTip: "天妒和遗计暂未接入，当前不能依靠受伤补牌。",
            implementationNote: "天妒、遗计尚未接入。"
        ),
        .init(
            .zhenJi,
            faction: "魏",
            strategy: "倾国让黑色牌具备防御价值，洛神则争取额外黑牌。可围绕黑牌安排手牌，不必只把黑牌视为弃牌。",
            openingTip: "优先保留黑牌用于防御，红牌和重复牌可作为其他用途。",
            newPlayerTip: "倾国和洛神暂未接入；当前防御仍要依靠手里的闪。",
            implementationNote: "倾国、洛神尚未接入。"
        ),
        .init(
            .liuBei,
            faction: "蜀",
            strategy: "刘备偏团队支援，仁德把多余手牌转成队友的行动力；主公时激将能联动蜀势力。",
            openingTip: "先看队友是否缺闪、桃或杀，再决定给牌；别把自己留到毫无防御。",
            newPlayerTip: "仁德和激将尚未接入，当前无法主动分牌或请求出杀。",
            implementationNote: "仁德、激将尚未接入。"
        ),
        .init(
            .guanYu,
            faction: "蜀",
            strategy: "武圣可把红色牌转化成杀，让装备和红牌都能形成进攻。注意计算攻击范围和对方闪的可能性。",
            openingTip: "红色重复牌可以作为进攻资源；仍留一张桃或闪应对风险。",
            newPlayerTip: "武圣转化尚未接入；普通红牌不能直接当杀使用。",
            implementationNote: "武圣尚未接入。"
        ),
        .init(
            .zhangFei,
            faction: "蜀",
            strategy: "咆哮允许连续出杀，适合积攒多张杀后集中压制一个重要目标。",
            openingTip: "先确认目标在攻击范围内，再按对方闪的数量安排杀；别把杀分散浪费。",
            newPlayerTip: "当前版本支持咆哮；连续杀仍要逐次结算响应。",
            implementationNote: "咆哮已接入。"
        ),
        .init(
            .zhugeLiang,
            faction: "蜀",
            strategy: "空城能保护空手牌的诸葛亮免受杀和决斗。观星若可用，还能调整下一轮摸牌顺序。",
            openingTip: "空城效果只在手牌为空时成立；判断是否弃光前，先看是否需要留闪或桃。",
            newPlayerTip: "当前支持空城，不支持观星；空手时仍可能受锦囊或其他伤害影响。",
            implementationNote: "空城已接入；观星尚未接入。"
        ),
        .init(
            .zhaoYun,
            faction: "蜀",
            strategy: "龙胆让杀和闪互相转换，手牌适应性很强。出牌时可把多余闪转成进攻，受杀时则能用杀防守。",
            openingTip: "同时保留一些可转换牌；先确认当前是出牌还是响应阶段。",
            newPlayerTip: "当前支持杀闪互换；牌仍会消耗，转换不能凭空增加手牌。",
            implementationNote: "龙胆的杀闪转换已接入。"
        ),
        .init(
            .maChao,
            faction: "蜀",
            strategy: "马术缩短与其他角色的距离，更容易把杀和顺手牵羊送到目标身上。铁骑可以压制闪响应。",
            openingTip: "用距离优势优先攻击关键角色；不要误以为距离近就能跳过目标规则。",
            newPlayerTip: "当前支持马术减距离，铁骑尚未接入。",
            implementationNote: "马术已接入；铁骑尚未接入。"
        ),
        .init(
            .huangYueYing,
            faction: "蜀",
            strategy: "集智鼓励连续使用锦囊；奇才则能扩大锦囊的目标范围。适合把过河拆桥、决斗等牌串成一轮节奏。",
            openingTip: "先评估手里的目标锦囊，再安排使用顺序；摸到的牌可能继续形成后续动作。",
            newPlayerTip: "当前仅部分锦囊会触发集智；奇才无距离限制尚未接入。",
            implementationNote: "集智已部分接入；奇才尚未接入。"
        ),
        .init(
            .sunQuan,
            faction: "吴",
            strategy: "制衡能替换手中不合时宜的牌，适合把当前局面用不上的牌换成新选择。",
            openingTip: "留下能立刻响应的闪、桃和有目标的杀，再制衡重复或暂时用不上的牌。",
            newPlayerTip: "制衡与救援主公技尚未接入，当前按普通四血武将行动。",
            implementationNote: "制衡、救援尚未接入。"
        ),
        .init(
            .ganNing,
            faction: "吴",
            strategy: "奇袭把黑色牌变成拆牌手段，能针对装备或关键手牌。使用前先判断哪张牌最影响对手计划。",
            openingTip: "留下一些黑牌发动奇袭，也要保留基本防御牌。",
            newPlayerTip: "奇袭尚未接入，黑色牌当前不能当过河拆桥。",
            implementationNote: "奇袭尚未接入。"
        ),
        .init(
            .lvMeng,
            faction: "吴",
            strategy: "克己鼓励谨慎出杀：若本回合没出杀，可以跳过弃牌，保存超出体力上限的手牌。",
            openingTip: "手牌重要且不需要进攻时，可以选择不出杀；若场上有关键击杀机会，先比较收益。",
            newPlayerTip: "当前支持未出杀时免弃牌；回合结束手牌可能多于体力。",
            implementationNote: "克己已接入。"
        ),
        .init(
            .huangGai,
            faction: "吴",
            strategy: "苦肉以体力换取手牌，爆发力强但会逼近濒死。要先有明确的用牌计划和救援把握。",
            openingTip: "不要在低体力时连续发动；先确认自己或队友能否提供桃。",
            newPlayerTip: "苦肉尚未接入，不要为了摸牌主动损失体力。",
            implementationNote: "苦肉尚未接入。"
        ),
        .init(
            .zhouYu,
            faction: "吴",
            strategy: "英姿稳定增加摸牌，手牌充足；反间能制造信息和伤害压力。适合灵活选择进攻或支援。",
            openingTip: "英姿多摸的牌先分出防御、进攻和可弃牌；不要在一回合里耗尽所有防御。",
            newPlayerTip: "当前支持英姿多摸一张；反间尚未接入。",
            implementationNote: "英姿已接入；反间尚未接入。"
        ),
        .init(
            .daQiao,
            faction: "吴",
            strategy: "国色用方块牌施加乐不思蜀，能限制高威胁角色的出牌阶段；流离可以转移杀的目标。",
            openingTip: "把方块牌留给需要限制的对手；使用乐不思蜀前确认对方判定区没有同名牌。",
            newPlayerTip: "国色和流离尚未接入；方块牌当前不会自动转化。",
            implementationNote: "国色、流离尚未接入。"
        ),
        .init(
            .luXun,
            faction: "吴",
            strategy: "谦逊能保护陆逊免受顺手牵羊，连营则能把空手状态转为补牌机会。",
            openingTip: "若规则允许，先规划何时打出最后一张手牌；留意对方是否有顺手牵羊。",
            newPlayerTip: "谦逊和连营尚未接入；不要依赖空手补牌。",
            implementationNote: "谦逊、连营尚未接入。"
        ),
        .init(
            .sunShangXiang,
            faction: "吴",
            strategy: "枭姬鼓励更新装备以补牌；结姻可用手牌帮助受伤男性角色回复。",
            openingTip: "更换装备前确认旧装备的收益；有队友受伤且手牌富余时再考虑结姻。",
            newPlayerTip: "枭姬和结姻尚未接入，装备更换不会额外摸牌。",
            implementationNote: "枭姬、结姻尚未接入。"
        ),
        .init(
            .huaTuo,
            faction: "群雄",
            strategy: "华佗偏救援和治疗。急救用红牌应对濒死，青囊帮助队友恢复；要把治疗资源留给关键时刻。",
            openingTip: "优先保留红牌和可用手牌；队友濒死时确认救援顺序和牌的合法性。",
            newPlayerTip: "急救与青囊尚未接入，当前不能把其他红牌当桃。",
            implementationNote: "急救、青囊尚未接入。"
        ),
        .init(
            .lvBu,
            faction: "群雄",
            strategy: "无双提高杀和决斗的响应压力，适合逼出对手防御牌后再进攻。",
            openingTip: "优先对防御牌少的目标使用杀；保留后续杀，给对手持续压力。",
            newPlayerTip: "无双尚未接入，当前杀和决斗仍按普通响应数量处理。",
            implementationNote: "无双尚未接入。"
        ),
        .init(.diaoChan, faction: "群雄", strategy: "离间让两名男性角色互相决斗，能转移战场压力；闭月提供回合结束补牌。", openingTip: "离间前观察双方的杀和体力，尽量让敌对角色承担决斗损失。", newPlayerTip: "离间与闭月尚未接入；暂时不能主动发起离间或结束摸牌。", implementationNote: "离间、闭月尚未接入。")
    ]

    public static func guide(for general: General) -> GeneralGuide {
        all.first { $0.general == general }!
    }
}
