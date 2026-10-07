import SanguoshaCore
import SwiftUI

private enum GuideSection: String, CaseIterable {
    case basics = "新手规则"
    case generals = "武将攻略"
}

struct RulesView: View {
    @State private var section: GuideSection = .basics
    private let general: General
    private let role: Role

    init(general: General, role: Role) {
        self.general = general
        self.role = role
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("指南", selection: $section) {
                Label("新手规则", systemImage: "book.closed").tag(GuideSection.basics)
                Label("武将攻略", systemImage: "person.text.rectangle").tag(GuideSection.generals)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(14)

            Divider()
            if section == .basics {
                basicsContent
            } else {
                GeneralGuideLibrary(initialGeneral: general, role: role)
            }
        }
        .frame(minWidth: 900, minHeight: 680)
        .background(Color(red: 0.95, green: 0.92, blue: 0.84))
        .preferredColorScheme(.light)
    }

    private var basicsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("第一次玩？从这里开始").font(.system(size: 26, weight: .bold, design: .serif))
                Text("你可以选择或随机获得身份和武将。支持 4–8 人身份局，主公、忠臣、反贼、内奸的人数会随局人数变化；主公身份公开，其余身份隐藏。观察谁在攻击谁，推理阵营。")
                ruleSection("胜利目标", "主公和忠臣：消灭反贼与内奸。反贼：杀死主公。内奸：除掉其他人，最后亲手成为唯一生还者。")
                ruleSection("每回合怎么走", "1. 摸两张牌。  2. 使用手牌。  3. 手牌多于当前体力时，弃到相同数量。然后轮到下一名存活角色。电脑行动会逐步播放，战报会保留并自动滚到最新行动。")
                ruleSection("基本牌", "杀：攻击攻击范围内角色。每回合通常一张；张飞与诸葛连弩可连续使用。目标可以打闪响应。\n\n闪：响应杀。赵云可以用杀当闪。\n\n桃：出牌阶段回复自己 1 点体力，也能在濒死时救援。标准牌堆不含酒。")
                ruleSection("锦囊与装备", "标准牌堆包含过河拆桥、顺手牵羊、决斗、南蛮入侵、万箭齐发、桃园结义、无中生有等锦囊，以及武器、防具和进攻马/防御马。选中牌后按提示选目标；装备会放到角色牌旁的装备区，并替换同类装备。")
                ruleSection("怎样判断身份", "反贼通常会攻击主公。忠臣会帮助主公，但也可能暂时不暴露身份。内奸需要控制局势，避免过早成为众矢之的。看行动和出牌，不要只看一次攻击。")
                ruleSection("牌堆与装备", "标准牌堆共 108 张，含基本牌 53 张、锦囊牌 36 张、装备牌 19 张；每张牌都有标准花色和点数。武器调整攻击范围，进攻马与防御马调整距离。八卦阵翻开牌堆顶一张牌：红色视为闪，黑色判定失败；判定牌进入弃牌堆。")
                ruleSection("当前规则边界", "闪电与乐不思蜀按判定牌结算；过河拆桥、顺手牵羊可选目标区域中的具体牌；借刀杀人会让持刀者对指定目标出杀或交刀。多目标锦囊的无懈可击尚未逐目标结算；多数武将技能和装备特效仍未实现。武将攻略会逐人标明当前实现情况。")
                Text("规则参考").font(.headline)
                Link("三国杀官方 FAQ：身份局获胜条件", destination: URL(string: "https://www.sanguosha.com/faq.html")!)
                Link("三国杀官方模式说明：身份场人数", destination: URL(string: "https://www.sanguosha.com/mode")!)
                Link("标准版 108 张牌表与 FAQ", destination: URL(string: "https://ks3-cn-beijing.ksyun.com/attachment/74ad98665ac744c138ba8c988d85d149")!)
                Link("三国杀规则集：基本牌", destination: URL(string: "https://gltjk.com/sanguosha/rules/card/basic.html")!)
                Link("三国杀规则集：回合流程", destination: URL(string: "https://gltjk.com/sanguosha/rules/flow/game.html")!)
            }
            .font(.body).foregroundStyle(.primary.opacity(0.88))
            .frame(maxWidth: 680, alignment: .leading).padding(28)
        }
    }

    private func ruleSection(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Color(red: 0.43, green: 0.20, blue: 0.12))
            Text(detail).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GeneralGuideLibrary: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedGeneral: General
    @State private var searchText = ""
    @State private var hoveredGeneral: General?

    private let role: Role

    init(initialGeneral: General, role: Role) {
        _selectedGeneral = State(initialValue: initialGeneral)
        self.role = role
    }

    private var filteredGenerals: [General] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return General.allCases }
        return General.allCases.filter { general in
            let guide = GeneralGuide.guide(for: general)
            return [general.title, general.skill, general.skillSummary, guide.faction, guide.strategy]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            generalList
                .frame(width: 250)
            Divider()
            guideDetail
        }
    }

    private var generalList: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索武将或技能", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("搜索武将或技能")
            }
            .padding(10)
            .frame(minHeight: 44)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 10)
            .padding(.top, 10)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(filteredGenerals, id: \.self) { general in
                        generalRow(general)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .background(Color(red: 0.91, green: 0.87, blue: 0.77))
    }

    private func generalRow(_ general: General) -> some View {
        let isSelected = selectedGeneral == general
        let isHovered = hoveredGeneral == general
        return Button {
            if reduceMotion { selectedGeneral = general }
            else { withAnimation(.easeInOut(duration: 0.18)) { selectedGeneral = general } }
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "person.fill")
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .white : Color(red: 0.43, green: 0.20, blue: 0.12))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(general.title).font(.headline)
                        Spacer(minLength: 4)
                        Text(GeneralGuide.guide(for: general).faction)
                            .font(.caption.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(isSelected ? .white.opacity(0.18) : .black.opacity(0.07), in: Capsule())
                    }
                    Text(general.skillSummary).font(.caption).lineLimit(2).multilineTextAlignment(.leading)
                }
                .foregroundStyle(isSelected ? .white : .primary.opacity(0.82))
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(rowBackground(isSelected: isSelected, isHovered: isHovered), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help("查看\(general.title)的技能说明和新手打法")
        .accessibilityLabel("\(general.title)，\(general.skillSummary)")
        .accessibilityHint("打开此武将的技能解析与攻略")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hoveredGeneral = $0 ? general : nil }
    }

    private func rowBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return Color(red: 0.43, green: 0.20, blue: 0.12) }
        return isHovered ? .white.opacity(0.8) : .clear
    }

    private var guideDetail: some View {
        let guide = GeneralGuide.guide(for: selectedGeneral)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 34)).foregroundStyle(Color(red: 0.63, green: 0.30, blue: 0.12))
                        .frame(width: 58, height: 58)
                        .background(.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedGeneral.title).font(.system(size: 28, weight: .bold, design: .serif))
                        Text("\(guide.faction)势力 · \(selectedGeneral.maxHP) 点体力 · 本局身份：\(role.title)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Label("标准版技能", systemImage: "sparkles")
                    .font(.headline).foregroundStyle(Color(red: 0.43, green: 0.20, blue: 0.12))
                Text(selectedGeneral.skill)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))

                guideSection("打法思路", symbol: "scope", detail: guide.strategy)
                guideSection("开局先看", symbol: "lightbulb", detail: guide.openingTip)
                guideSection("新手提醒", symbol: "hand.raised", detail: guide.newPlayerTip)
                guideSection("当前版本实现", symbol: "gearshape.2", detail: guide.implementationNote)
                guideSection("按你的身份行动", symbol: "person.3", detail: identityAdvice)
                Text("提示：武将技能按标准版规则介绍；未完成的效果已在“当前版本实现”中标出。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.92, blue: 0.84))
    }

    private var identityAdvice: String {
        switch role {
        case .lord: "主公：优先活下来并保护身份明确的队友。不要只因为某人攻击过你就认定他是反贼，结合多轮行动判断。"
        case .loyalist: "忠臣：帮助主公存活并集中处理反贼、内奸。必要时先用防御牌保护主公，避免误伤主公阵营。"
        case .rebel: "反贼：目标是主公。与其他反贼协同施压，优先削弱主公的防御，同时避免过早暴露后被逐个击破。"
        case .spy: "内奸：前期控制强弱平衡，避免过早成为集火目标；等其他阵营消耗后，再争取单独取胜。"
        }
    }

    private func guideSection(_ title: String, symbol: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.headline).foregroundStyle(Color(red: 0.43, green: 0.20, blue: 0.12))
            Text(detail).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 12))
    }
}
