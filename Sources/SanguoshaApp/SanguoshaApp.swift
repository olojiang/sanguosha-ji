import SanguoshaCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct SanguoshaJiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: 900, minHeight: 860).preferredColorScheme(.dark)
        }
    }
}

private struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var game = GameEngine.newGame(humanGeneral: nil, humanRole: nil, generalPool: General.allCases, playerCount: 4)
    @State private var selectedCardID: Int?
    @State private var hoveredCardID: Int?
    @State private var handOrder: [Int] = []
    @State private var draggedCardID: Int?
    @State private var showRules = false
    @State private var message: String?
    @State private var isAIPlaying = false
    @State private var aiTask: Task<Void, Never>?
    @State private var damagedPlayers = Set<Int>()
    @State private var selectedRole: Role?
    @State private var selectedGeneral: General?
    @State private var selectedPlayerCount = 4
    @State private var voicePlayer = CardVoicePlayer()
    @State private var isVoiceSpeaking = false

    private let felt = Color(red: 0.055, green: 0.18, blue: 0.16)

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 800
            let logHeight = compact ? 170 : max(190, min(240, geometry.size.height * 0.22))
            ZStack {
                LinearGradient(colors: [Color(red: 0.04, green: 0.10, blue: 0.10), Color(red: 0.02, green: 0.06, blue: 0.07)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                VStack(spacing: compact ? 8 : 14) {
                    header
                    HStack(spacing: compact ? 12 : 18) {
                        table(logHeight: logHeight, compact: compact)
                        helpPanel.frame(width: min(255, max(220, geometry.size.width * 0.26)))
                    }
                    playerControls
                }
                .padding(.horizontal, geometry.size.width < 1000 ? 16 : 22)
                .padding(.top, 16)
                .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showRules) { RulesView(general: game.human.general, role: game.human.role) }
        .alert("提示", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("知道了", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .alert(game.winner.map(winnerTitle) ?? "", isPresented: Binding(get: { game.winner != nil }, set: { _ in })) {
            Button("再开一局") { newGame(role: selectedRole, general: selectedGeneral) }
        } message: { Text(winnerMessage) }
        .background(LaunchWindowMaximizer())
        .onAppear {
            handOrder = HandOrder.reconciling(handOrder, with: game.human.hand.map(\.id))
        }
        .onChange(of: game.human.hand.map(\.id)) { _, ids in
            handOrder = HandOrder.reconciling(handOrder, with: ids)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("三国杀 · 身份局").font(.system(size: 26, weight: .bold, design: .serif))
                Text("你是\(game.human.role.title) · \(game.human.general.title) · \(game.players.count) 人局").font(.callout).foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            if isVoiceSpeaking { Label("语音播报中", systemImage: "waveform").font(.caption).foregroundStyle(.orange) }
            Menu {
                Button("随机身份") { newGame(role: nil, general: selectedGeneral) }
                Divider()
                ForEach(Role.allCases, id: \.self) { role in
                    Button(role.title) { newGame(role: role, general: selectedGeneral) }
                }
            } label: { Label("身份：\(game.human.role.title)", systemImage: "person.3") }
                .buttonStyle(.bordered)
            Menu {
                Button("随机武将") { newGame(role: selectedRole, general: nil) }
                Divider()
                ForEach(General.allCases, id: \.self) { general in
                    Button { newGame(role: selectedRole, general: general) } label: { Text("\(general.title) · \(general.maxHP)体力 · \(general.skill)") }
                }
            } label: { Label("武将：\(game.human.general.title)", systemImage: "person.crop.circle.badge.checkmark") }
                .buttonStyle(.bordered)
            Menu {
                ForEach(IdentityConfiguration.supportedPlayerCounts, id: \.self) { count in
                    let summary = IdentityConfiguration.summary(forPlayerCount: count) ?? ""
                    Button("\(count) 人局 · \(summary)") {
                        newGame(role: selectedRole, general: selectedGeneral, playerCount: count)
                    }
                }
            } label: { Label("\(game.players.count)人", systemImage: "person.3") }
                .buttonStyle(.bordered)
            Button { showRules = true } label: { Label("新手规则", systemImage: "book.closed") }.buttonStyle(.bordered)
            Button { newGame(role: selectedRole, general: selectedGeneral) } label: { Label("重新开始", systemImage: "arrow.clockwise") }
                .buttonStyle(.borderedProminent).tint(Color(red: 0.65, green: 0.31, blue: 0.18))
        }
    }

    private func table(logHeight: CGFloat, compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 12) {
            if game.players.count == 4 { fourPlayerSeats(compact: compact) }
            else { multiplayerSeats(compact: compact) }
            logView.frame(height: logHeight)
        }
        .padding(compact ? 12 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 24).fill(felt).overlay {
            RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 1)
        })
        .overlay(alignment: .topTrailing) {
            Text("牌堆  \(game.drawPile.count)").font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.65)).padding(12)
        }
    }

    private func fourPlayerSeats(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 12) {
            playerTile(2)
            HStack(spacing: 12) {
                playerTile(3)
                phaseSummary(compact: compact).frame(maxWidth: .infinity, maxHeight: .infinity)
                playerTile(1)
            }
            playerTile(0)
        }
    }

    private func multiplayerSeats(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            phaseSummary(compact: compact)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 330), spacing: 8)], spacing: 8) {
                    ForEach(game.players.indices, id: \.self) { playerTile($0) }
                }
            }.scrollIndicators(.visible)
        }
    }

    private func phaseSummary(compact: Bool) -> some View {
        VStack(spacing: compact ? 5 : 8) {
            Image(systemName: "sparkle").font(.system(size: compact ? 19 : 25)).foregroundStyle(.orange.opacity(0.85))
            Text("身份局").font(.headline)
            Text(phaseHint).font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.9)).frame(maxWidth: 320, minHeight: compact ? 34 : 45)
        }.frame(maxWidth: .infinity)
    }

    private func playerTile(_ id: Int) -> some View {
        let player = game.players[id]
        let isTurn = game.currentPlayerID == id && game.winner == nil
        let collateralOwnerID = choosingCollateralWeaponOwnerID
        let isCollateralVictim = collateralOwnerID.map { game.canTarget(id, with: .slash, from: $0) } ?? false
        let isSpearTarget: Bool = if case .choosingSpearTarget = game.phase { game.canTarget(id, with: .slash, from: 0) } else { false }
        let canTarget = isCollateralVictim || isSpearTarget || (selectedTargetCard.map { game.phase == .action && game.canTarget(id, with: $0.kind, from: 0) } ?? false)
        let isRecentAction = game.log.suffix(3).contains { $0.contains(player.name) }
        let isDamaged = damagedPlayers.contains(id)
        return Button {
            if isCollateralVictim { chooseCollateralTarget(id) }
            else if isSpearTarget { useSpearSlash(on: id) }
            else if canTarget { playSelected(on: id) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(player.isAlive ? Color(red: 0.55, green: 0.32, blue: 0.19) : .gray.opacity(0.3))
                    Image(systemName: player.role == .lord ? "crown.fill" : "person.fill").font(.system(size: 20)).foregroundStyle(.white.opacity(player.isAlive ? 0.9 : 0.35))
                }.frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(id + 1)号位").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                        Text(player.general.title).font(.headline)
                        if player.isHuman { badge("你", color: .blue) }
                        if player.role == .lord { badge("主公", color: .orange) }
                        if isTurn { Image(systemName: "arrowtriangle.left.fill").font(.caption2).foregroundStyle(.yellow).symbolEffect(.pulse, options: .repeating, isActive: isAIPlaying) }
                    }
                    Text(player.general.skillSummary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    HStack(spacing: 3) {
                        ForEach(0..<player.maxHP, id: \.self) { index in
                            Image(systemName: index < player.hp ? "heart.fill" : "heart").font(.caption2)
                                .foregroundStyle(index < player.hp ? .red.opacity(0.9) : .white.opacity(0.22))
                        }
                        Text("体力 \(player.healthStatus)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.82))
                        Text("  \(player.hand.count) 张手牌").font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    HStack(spacing: 4) {
                        ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                            if let card = player.equipment[slot] {
                                Text(card.title).font(.system(size: 9, weight: .medium)).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(.orange.opacity(0.18), in: Capsule())
                            }
                        }
                        ForEach(player.delayedTricks) { card in
                            Text("判定·\(card.title)").font(.system(size: 9, weight: .medium)).padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.purple.opacity(0.22), in: Capsule())
                        }
                    }
                }
                Spacer(minLength: 0)
                if !player.isAlive { Text("阵亡").font(.caption).foregroundStyle(.gray) }
                else if isCollateralVictim { Text("借刀目标").font(.caption.weight(.bold)).foregroundStyle(.orange) }
                else if canTarget { Text(isSpearTarget ? "丈八蛇矛目标" : (selectedTargetCard?.kind == .collateral ? "持刀角色" : "攻击")).font(.caption.weight(.bold)).foregroundStyle(.orange) }
            }
            .padding(10).frame(maxWidth: .infinity, minHeight: 78)
            .background(RoundedRectangle(cornerRadius: 16).fill(isDamaged ? Color.red.opacity(0.28) : (isTurn ? Color.white.opacity(0.14) : Color.black.opacity(0.18))))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDamaged ? .red : (canTarget ? .orange : (isTurn ? .yellow.opacity(0.55) : (isRecentAction ? .orange.opacity(0.45) : .white.opacity(0.1)))), lineWidth: isDamaged || canTarget || isTurn || isRecentAction ? 1.5 : 1))
            .scaleEffect(isDamaged ? 1.025 : 1)
            .shadow(color: isDamaged ? .red.opacity(0.65) : .clear, radius: isDamaged ? 15 : 0)
            .opacity(player.isAlive ? 1 : 0.5)
        }
        .buttonStyle(.plain).disabled(!canTarget || isVoiceSpeaking || isAIPlaying)
        .animation(.easeInOut(duration: 0.35), value: isRecentAction)
        .animation(.spring(response: 0.28, dampingFraction: 0.45), value: isDamaged)
        .onChange(of: player.hp) { oldHP, newHP in
            guard newHP < oldHP else { return }
            _ = withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { damagedPlayers.insert(id) }
            Task {
                try? await Task.sleep(for: .milliseconds(460))
                _ = withAnimation(.easeOut(duration: 0.3)) { damagedPlayers.remove(id) }
            }
        }
        .help("\(player.general.title)：\(player.general.skill)\n\(player.isHuman ? "你的身份是\(player.role.title)。" : (player.role == .lord ? "主公身份公开。" : "身份未知；观察对方行动来判断。"))")
    }

    private var helpPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("你的目标", systemImage: "target").font(.headline)
            Text(objectiveText)
                .font(.subheadline).foregroundStyle(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
            Divider().overlay(.white.opacity(0.15))
            Text("本回合").font(.headline)
            Text(phaseHint).font(.subheadline).foregroundStyle(.orange.opacity(0.95)).fixedSize(horizontal: false, vertical: true)
            Text("你的武将").font(.headline)
            Text("\(game.human.general.title) · \(game.human.general.skill)")
                .font(.subheadline).foregroundStyle(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
            Text("小提示").font(.headline)
            Text("点选手牌，再按说明操作。武器和坐骑会改变距离。红心越少，体力越低。")
                .font(.subheadline).foregroundStyle(.white.opacity(0.68)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { showRules = true } label: { Label("查看完整入门说明", systemImage: "questionmark.circle") }
                .buttonStyle(.plain).foregroundStyle(.orange)
        }
        .padding(18).frame(maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.055)))
    }

    private var playerControls: some View {
        VStack(spacing: 12) {
            if case .awaitingDodge(targetID: 0, _) = game.phase {
                HStack {
                    Text("\(game.players[game.currentAttackerID ?? 0].name) 对你使用【\(game.responseCardKind.title)】。要响应吗？")
                    Spacer()
                    Button("承受伤害") { respondToSlash(useDodge: false) }.buttonStyle(.bordered).disabled(isVoiceSpeaking || isAIPlaying)
                    Button(responseButtonTitle) { respondToSlash(useDodge: true) }
                        .buttonStyle(.borderedProminent).tint(.blue).disabled(!canRespondWithDodge || isVoiceSpeaking || isAIPlaying)
                }
                .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            if case .respondingToTrick(responderID: 0) = game.phase {
                HStack {
                    Text("是否打出无懈可击，抵消\(game.trickResponseSummary ?? "当前锦囊")？")
                    Spacer()
                    Button("不使用") { respondToTrick(useNullification: false) }
                        .buttonStyle(.bordered).disabled(isVoiceSpeaking || isAIPlaying)
                    Button("打出无懈可击") { respondToTrick(useNullification: true) }
                        .buttonStyle(.borderedProminent).tint(.blue)
                        .disabled(!game.human.hand.contains { $0.kind == .nullification } || isVoiceSpeaking || isAIPlaying)
                }
                .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            if case let .awaitingDuelSlash(responderID, challengerID) = game.phase, responderID == 0 {
                HStack {
                    Text("你正在与\(game.players[challengerID].name)决斗：打出【杀】或受到 1 点伤害。")
                    Spacer()
                    Button("不出杀") { respondToDuel(useSlash: false) }
                        .buttonStyle(.bordered).disabled(isVoiceSpeaking || isAIPlaying)
                    Button("打出杀") { respondToDuel(useSlash: true) }
                        .buttonStyle(.borderedProminent).tint(.blue)
                        .disabled(!game.human.hand.contains { $0.kind == .slash } || isVoiceSpeaking || isAIPlaying)
                }
                .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            if case let .awaitingCollateralSlash(sourceID, weaponOwnerID, targetID) = game.phase,
               weaponOwnerID == 0 {
                HStack {
                    Label("借刀杀人：对\(game.players[targetID].general.title)使用杀，或把武器交给\(game.players[sourceID].general.title)。", systemImage: "arrowshape.turn.up.right")
                    Spacer()
                    Button { respondToCollateral(useSlash: false) } label: { Label("交出武器", systemImage: "arrowshape.turn.up.right") }
                        .buttonStyle(.bordered).disabled(isVoiceSpeaking || isAIPlaying)
                    Button { respondToCollateral(useSlash: true) } label: { Label("打出杀", systemImage: "hand.raised.fill") }
                        .buttonStyle(.borderedProminent).tint(.blue)
                        .disabled(!game.human.hand.contains { $0.kind == .slash } || isVoiceSpeaking || isAIPlaying)
                }
                .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            if case let .dying(targetID, responderID) = game.phase, responderID == 0 {
                HStack {
                    Text("\(game.players[targetID].name) 濒死了。你可以打出桃救援。")
                    Spacer()
                    Button("不救") { respondToDying(usePeach: false) }.buttonStyle(.bordered).disabled(isVoiceSpeaking || isAIPlaying)
                    Button("打出桃") { respondToDying(usePeach: true) }.buttonStyle(.borderedProminent).tint(.red)
                        .disabled(!game.human.hand.contains(where: { $0.kind == .peach }) || isVoiceSpeaking || isAIPlaying)
                }
                .padding(12).background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            weaponChoicePrompt
            Group {
                if case let .choosingIceSwordCard(sourceID: 0, targetID, remaining) = game.phase {
                    weaponTargetCardSelectionView(title: "寒冰剑", targetID: targetID, detail: "还需选择弃置 \(remaining) 张手牌或装备")
                } else if case let .choosingKylinBowHorse(sourceID: 0, targetID) = game.phase {
                    weaponTargetCardSelectionView(title: "麒麟弓", targetID: targetID, detail: "选择弃置一匹马；杀仍会造成伤害")
                } else if case let .choosingAxeCosts(sourceID: 0, targetID, selectedIDs) = game.phase {
                    axeCostSelectionView(targetID: targetID, selectedIDs: selectedIDs)
                } else if case let .choosingSpearCosts(selectedIDs) = game.phase {
                    spearCostSelectionView(selectedIDs: selectedIDs)
                } else if case let .choosingSpearTarget(selectedIDs) = game.phase {
                    spearTargetSelectionView(selectedIDs: selectedIDs)
                } else if case let .choosingTargetCard(sourceID: 0, targetID, kind) = game.phase {
                    targetCardSelectionView(targetID: targetID, kind: kind)
                } else if case let .choosingHarvest(playerID) = game.phase, playerID == 0 {
                    harvestSelectionView
                } else {
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("你的手牌").font(.title3.weight(.bold))
                                Text("体力 \(game.human.hp)/\(game.human.maxHP) · 手牌上限 \(game.human.hp) · 装备会显示在角色旁")
                                    .font(.footnote).foregroundStyle(.white.opacity(0.68))
                            }
                            Text(handInteractionHint)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(selectedTargetCard == nil ? .white.opacity(0.62) : .orange)
                            cardHoverHelp
                            ScrollView(.horizontal) {
                                HStack(spacing: 12) { ForEach(orderedHand) { card in cardButton(card) } }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: game.human.hand.map(\.id))
                            }
                            .scrollIndicators(.hidden)
                            .frame(height: 222)
                        }
                        Spacer(minLength: 4)
                        turnButton
                    }
                }
            }
            .padding(12)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var weaponChoicePrompt: some View {
        switch game.phase {
        case let .awaitingDoubleSwordChoice(sourceID, targetID) where targetID == 0:
            HStack(spacing: 10) {
                Label("雌雄双股剑：选择弃一张手牌，或让\(game.players[sourceID].general.title)摸一张。", systemImage: "arrow.left.arrow.right")
                Spacer()
                Button { run { try game.respondToDoubleSword(discardCardID: nil) }; startAIPlayback() } label: { Label("让其摸牌", systemImage: "square.stack") }
                    .buttonStyle(.bordered).help("不弃牌，由攻击者摸一张").disabled(isVoiceSpeaking || isAIPlaying)
                ForEach(game.human.hand) { card in
                    Button { run { try game.respondToDoubleSword(discardCardID: card.id) }; startAIPlayback() } label: { Label("弃【\(card.title)】", systemImage: "trash") }
                        .buttonStyle(.borderedProminent).tint(.orange).help("弃置这张手牌，避免攻击者摸牌").disabled(isVoiceSpeaking || isAIPlaying)
                }
            }
            .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        case let .awaitingIceSwordChoice(sourceID, targetID) where sourceID == 0:
            HStack {
                Label("寒冰剑：放弃本次伤害，改为弃置\(game.players[targetID].general.title)至多两张手牌或装备？", systemImage: "snowflake")
                Spacer()
                Button { run { try game.chooseIceSword(use: false) }; startAIPlayback() } label: { Label("造成伤害", systemImage: "heart.fill") }
                    .buttonStyle(.bordered).help("不发动寒冰剑，杀正常造成伤害").disabled(isVoiceSpeaking || isAIPlaying)
                Button { run { try game.chooseIceSword(use: true) }; startAIPlayback() } label: { Label("发动寒冰剑", systemImage: "snowflake") }
                    .buttonStyle(.borderedProminent).tint(.blue).help("防止伤害并选择弃置目标的牌").disabled(isVoiceSpeaking || isAIPlaying)
            }
            .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        case let .awaitingAxeChoice(sourceID, targetID) where sourceID == 0:
            HStack {
                Label("贯石斧：\(game.players[targetID].general.title)已闪避。弃两张其他牌可令杀命中。", systemImage: "hammer.fill")
                Spacer()
                Button { run { try game.chooseAxe(use: false) }; startAIPlayback() } label: { Label("接受闪避", systemImage: "xmark") }
                    .buttonStyle(.bordered).help("不弃牌，杀被闪避").disabled(isVoiceSpeaking || isAIPlaying)
                Button { run { try game.chooseAxe(use: true) }; startAIPlayback() } label: { Label("选择两张牌", systemImage: "hand.raised") }
                    .buttonStyle(.borderedProminent).tint(.orange).help("选择两张手牌或装备作为弃牌代价").disabled(isVoiceSpeaking || isAIPlaying)
            }
            .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        case let .awaitingKylinBowChoice(sourceID, targetID) where sourceID == 0:
            HStack {
                Label("麒麟弓：杀命中后，可弃置\(game.players[targetID].general.title)装备区的一匹马。", systemImage: "scope")
                Spacer()
                Button { run { try game.chooseKylinBow(use: false) }; startAIPlayback() } label: { Label("不弃马", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.bordered).help("保留目标的马，杀仍造成伤害").disabled(isVoiceSpeaking || isAIPlaying)
                Button { run { try game.chooseKylinBow(use: true) }; startAIPlayback() } label: { Label("选择马匹", systemImage: "horse") }
                    .buttonStyle(.borderedProminent).tint(.orange).help("选择目标装备区的一匹马弃置").disabled(isVoiceSpeaking || isAIPlaying)
            }
            .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        default: EmptyView()
        }
    }

    private func weaponTargetCardSelectionView(title: String, targetID: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(title)：选择\(game.players[targetID].general.title)的一张牌", systemImage: "hand.tap")
                .font(.headline).foregroundStyle(.orange)
            Text(detail).font(.caption).foregroundStyle(.white.opacity(0.72))
            ScrollView(.horizontal) {
                HStack(spacing: 12) { ForEach(game.targetCardOptions) { option in targetCardOptionButton(option) } }
                    .padding(.horizontal, 16).padding(.vertical, 18)
            }
            .scrollIndicators(.hidden).frame(height: 222)
        }
        .padding(12).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func axeCostSelectionView(targetID: Int, selectedIDs: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("贯石斧：选择两张牌弃置，强制命中\(game.players[targetID].general.title)", systemImage: "hammer.fill")
                    .font(.headline).foregroundStyle(.orange)
                Spacer()
                Text("已选 \(selectedIDs.count)/2").font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.8))
                Button { run { try game.confirmAxeCosts() }; startAIPlayback() } label: { Label("确认弃置", systemImage: "checkmark.circle.fill") }
                    .buttonStyle(.borderedProminent).tint(.orange).help("弃置选中的两张牌并强制命中")
                    .disabled(selectedIDs.count != 2 || isVoiceSpeaking || isAIPlaying)
            }
            Text("可选手牌或装备；贯石斧本身不能作为代价。")
                .font(.caption).foregroundStyle(.white.opacity(0.72))
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(game.axeCostOptions) { option in
                        Button { run { try game.toggleAxeCost(cardID: option.id) } } label: {
                            VStack(spacing: 4) {
                                cardFace(option.card, selected: selectedIDs.contains(option.id), isHovered: false, isHarvest: true)
                                Text(option.zone.title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.78))
                            }
                        }
                        .buttonStyle(.plain).help("选择弃置【\(option.card.title)】· \(option.zone.title)")
                        .disabled(isVoiceSpeaking || isAIPlaying || (!selectedIDs.contains(option.id) && selectedIDs.count == 2))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 18)
            }
            .scrollIndicators(.hidden).frame(height: 222)
        }
        .padding(12).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func spearCostSelectionView(selectedIDs: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("丈八蛇矛：选择两张手牌当作杀", systemImage: "arrow.left.arrow.right")
                    .font(.headline).foregroundStyle(.orange)
                Spacer()
                Text("已选 \(selectedIDs.count)/2").font(.subheadline.weight(.bold))
                Button { run { try game.confirmSpearCosts() } } label: { Label("选择目标", systemImage: "checkmark.circle.fill") }
                    .buttonStyle(.borderedProminent).tint(.orange).help("确认两张手牌，然后选择杀的目标")
                    .disabled(selectedIDs.count != 2 || isVoiceSpeaking || isAIPlaying)
                Button { game.cancelSpearSlash() } label: { Label("取消", systemImage: "xmark.circle") }
                    .buttonStyle(.bordered).help("取消丈八蛇矛的使用，不弃牌")
            }
            Text("只从手牌中选择；确认目标前不会弃牌。").font(.caption).foregroundStyle(.white.opacity(0.72))
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(orderedHand) { card in
                        Button { run { try game.toggleSpearCost(cardID: card.id) } } label: {
                            cardFace(card, selected: selectedIDs.contains(card.id), isHovered: hoveredCardID == card.id, isHarvest: true)
                        }
                        .buttonStyle(.plain).help("选择【\(card.title)】作为丈八蛇矛代价")
                        .disabled(isVoiceSpeaking || isAIPlaying || (!selectedIDs.contains(card.id) && selectedIDs.count == 2))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 18)
            }
            .scrollIndicators(.hidden).frame(height: 222)
        }
        .padding(12).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func spearTargetSelectionView(selectedIDs: [Int]) -> some View {
        HStack {
            Label("已选两张手牌当杀：请点击桌面上的合法目标。", systemImage: "scope")
            Spacer()
            Button { game.cancelSpearSlash() } label: { Label("取消", systemImage: "xmark.circle") }
                .buttonStyle(.bordered).help("取消丈八蛇矛的使用，不弃牌")
        }
        .padding(12).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("已选择 \(selectedIDs.count) 张牌，选择丈八蛇矛杀的目标")
    }

    private func cardButton(_ card: Card) -> some View {
        let chosen = selectedCardID == card.id
        let hovering = hoveredCardID == card.id
        return Button { select(card) } label: {
            cardFace(card, selected: chosen, isHovered: hovering, isHarvest: false)
        }
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.75)).combined(with: .opacity), removal: .scale(scale: 0.85).combined(with: .opacity)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(.plain).help(card.kind.tooltipText)
        .onHover { isHovering in hoveredCardID = isHovering ? card.id : nil }
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: hovering)
        .onDrag {
            draggedCardID = card.id
            return NSItemProvider(object: String(card.id) as NSString)
        }
        .onDrop(of: [UTType.text], delegate: HandCardDropDelegate(
            targetID: card.id, orderedIDs: $handOrder, draggedID: $draggedCardID, reduceMotion: reduceMotion
        ))
        .contextMenu {
            Button { moveCard(card.id, by: -1) } label: { Label("向左移动", systemImage: "arrow.left") }
                .disabled(!canMoveCard(card.id, by: -1))
            Button { moveCard(card.id, by: 1) } label: { Label("向右移动", systemImage: "arrow.right") }
                .disabled(!canMoveCard(card.id, by: 1))
        }
        .accessibilityLabel("\(card.title)，手牌编号 \(card.id)")
        .accessibilityHint("任何阶段都可拖动整理手牌，或打开操作菜单移动。出牌阶段点击可选择；需要目标时再点桌面上高亮的角色。")
        .accessibilityIdentifier("card-\(card.id)")
    }

    private var harvestSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("五谷丰登：从亮出的牌中选择一张")
                .font(.title3.weight(.bold))
            Text("所有存活角色各选一张；现在轮到你。")
                .font(.footnote).foregroundStyle(.white.opacity(0.7))
            cardHoverHelp
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(game.harvestChoices) { card in harvestChoiceButton(card) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden).frame(height: 222)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
    }

    private func harvestChoiceButton(_ card: Card) -> some View {
        let hovering = hoveredCardID == card.id
        return Button {
            run { try game.chooseHarvest(cardID: card.id, by: 0) }
            startAIPlayback()
        } label: {
            cardFace(card, selected: false, isHovered: hovering, isHarvest: true)
        }
        .buttonStyle(.plain)
        .onHover { hoveredCardID = $0 ? card.id : nil }
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: hovering)
        .help(card.kind.tooltipText)
        .disabled(isVoiceSpeaking || isAIPlaying)
        .accessibilityIdentifier("harvest-choice-\(card.id)")
    }

    private func cardFace(_ card: Card, selected: Bool, isHovered: Bool, isHarvest: Bool) -> some View {
        VStack(spacing: 5) {
            CardIllustrationView(index: card.kind.illustrationIndex)
                .frame(width: 112, height: 132)
                .scaleEffect(isHovered && !reduceMotion ? 1.035 : 1)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
            Text(card.title)
                .font(.system(size: card.title.count > 5 ? 14 : 19, weight: .bold, design: .serif))
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(card.category.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
        }
        .frame(width: 142, height: 184)
        .foregroundStyle(isHarvest ? Color.black : card.kind == .dodge ? Color.blue : card.kind == .peach ? Color.red : Color.black)
        .background(RoundedRectangle(cornerRadius: 14).fill(isHovered ? Color(red: 0.99, green: 0.95, blue: 0.85) : Color(red: 0.94, green: 0.91, blue: 0.82)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected || isHovered ? .orange : .white.opacity(0.5), lineWidth: selected || isHovered ? 2.5 : 1))
        .shadow(color: isHovered ? .orange.opacity(0.32) : .clear, radius: 12, y: 4)
    }

    private var orderedHand: [Card] {
        let byID = Dictionary(uniqueKeysWithValues: game.human.hand.map { ($0.id, $0) })
        return HandOrder.reconciling(handOrder, with: game.human.hand.map(\.id)).compactMap { byID[$0] }
    }

    private func canMoveCard(_ id: Int, by offset: Int) -> Bool {
        guard let index = orderedHand.firstIndex(where: { $0.id == id }) else { return false }
        return orderedHand.indices.contains(index + offset)
    }

    private func moveCard(_ id: Int, by offset: Int) {
        guard canMoveCard(id, by: offset), let index = handOrder.firstIndex(of: id) else { return }
        let target = index + offset
        guard handOrder.indices.contains(target) else { return }
        var reordered = handOrder
        reordered.swapAt(index, target)
        if reduceMotion { handOrder = reordered }
        else { withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) { handOrder = reordered } }
    }

    private func targetCardSelectionView(targetID: Int, kind: CardKind) -> some View {
        let target = game.players[targetID]
        return VStack(alignment: .leading, spacing: 8) {
            Label("\(kind.title)：选择\(target.general.title)区域中的一张牌", systemImage: "hand.tap")
                .font(.headline).foregroundStyle(.orange)
            Text("暗置手牌不会公开牌面；装备区和判定区的牌会显示名称。")
                .font(.caption).foregroundStyle(.white.opacity(0.68))
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(game.targetCardOptions) { option in targetCardOptionButton(option) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
            .frame(height: 250)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func targetCardOptionButton(_ option: TargetCardOption) -> some View {
        Button { chooseSelectedTargetCard(option.id) } label: {
            Group {
                if option.zone.isHidden {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(
                            LinearGradient(colors: [Color(red: 0.22, green: 0.34, blue: 0.34), Color(red: 0.08, green: 0.17, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.35), lineWidth: 1).padding(7)
                        VStack(spacing: 9) {
                            Image(systemName: "questionmark.square.dashed").font(.system(size: 36, weight: .light))
                            Text("暗置手牌").font(.headline)
                            Text("选择此张").font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(width: 142, height: 184)
                } else {
                    VStack(spacing: 4) {
                        cardFace(option.card, selected: false, isHovered: false, isHarvest: true)
                        Text(option.zone.title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.78))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .help(option.zone.isHidden ? "选择一张暗置手牌；牌面不会公开。" : "\(option.card.kind.tooltipText) · \(option.zone.title)")
        .accessibilityLabel(option.zone.isHidden ? "选择一张暗置手牌" : "选择\(option.zone.title)的\(option.card.title)")
    }

    private func chooseTargetCard(_ id: Int) {
        run { try game.chooseTargetCard(cardID: id) }
        startAIPlayback()
    }

    private func chooseSelectedTargetCard(_ id: Int) {
        switch game.phase {
        case .choosingIceSwordCard:
            run { try game.chooseIceSwordCard(cardID: id) }
        case .choosingKylinBowHorse:
            run { try game.chooseKylinBowHorse(cardID: id) }
        default:
            chooseTargetCard(id)
            return
        }
        startAIPlayback()
    }

    private var choosingCollateralWeaponOwnerID: Int? {
        guard case let .choosingCollateralTarget(_, weaponOwnerID) = game.phase else { return nil }
        return weaponOwnerID
    }

    private func chooseCollateralTarget(_ id: Int) {
        run { try game.chooseCollateralTarget(id) }
        startAIPlayback()
    }

    private func useSpearSlash(on targetID: Int) {
        run { try game.chooseSpearTarget(targetID) }
        startAIPlayback()
    }

    private func respondToCollateral(useSlash: Bool) {
        run { try game.respondToCollateral(withSlash: useSlash) }
        startAIPlayback()
    }

    private var cardHoverHelp: some View {
        Group {
            if let card = hoveredCard {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(card.title) · \(card.category.title)").font(.caption.weight(.bold))
                        Text(card.kind.helpText).font(.caption).lineLimit(2).foregroundStyle(.white.opacity(0.82))
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityIdentifier("card-hover-help")
            } else {
                Text("任何阶段都能拖动整理手牌；出牌阶段点击使用。悬停可查看牌的作用。")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
    }

    private var hoveredCard: Card? {
        game.human.hand.first { $0.id == hoveredCardID }
            ?? game.harvestChoices.first { $0.id == hoveredCardID }
    }

    @ViewBuilder
    private var turnButton: some View {
        Group {
            switch game.phase {
            case .drawing:
                Button { run { try game.drawForTurn() }; startAIPlayback() } label: { Label("摸两张牌", systemImage: "square.stack.3d.up") }
                    .buttonStyle(.borderedProminent).tint(.orange).controlSize(.large)
            case .action:
                HStack {
                    if game.canBeginSpearSlash {
                        Button { run { try game.beginSpearSlash() } } label: { Label("蛇矛当杀", systemImage: "arrow.left.arrow.right") }
                            .buttonStyle(.borderedProminent).tint(.orange).controlSize(.large)
                            .help("弃两张手牌当杀使用").accessibilityLabel("丈八蛇矛弃两张手牌当杀")
                    }
                    Button { finishTurn() } label: { Label("结束回合", systemImage: "arrow.right.circle.fill") }
                        .buttonStyle(.borderedProminent).tint(Color(red: 0.65, green: 0.31, blue: 0.18)).controlSize(.large)
                }
            case .choosingHarvest, .choosingTargetCard, .choosingCollateralTarget, .awaitingCollateralSlash,
                 .awaitingDodge, .awaitingDuelSlash, .respondingToTrick, .dying, .gameOver,
                 .awaitingDoubleSwordChoice, .awaitingIceSwordChoice, .choosingIceSwordCard,
                 .awaitingAxeChoice, .choosingAxeCosts, .awaitingKylinBowChoice, .choosingKylinBowHorse,
                 .choosingSpearCosts, .choosingSpearTarget: EmptyView()
            }
        }
        .disabled(isAIPlaying || isVoiceSpeaking || game.currentPlayerID != 0)
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 7) {
            recentActivityView
            Divider().overlay(.white.opacity(0.16))
            HStack {
                Text("完整历史").font(.caption.weight(.semibold))
                Spacer()
                Text("\(game.log.count) 条 · 自动跟随最新行动").font(.caption2).foregroundStyle(.white.opacity(0.56))
            }
            historyScrollView
        }
        .padding(12).background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("行动速览和完整历史")
    }

    private var logPresentation: GameLogPresentation { GameLogPresentation(players: game.players) }

    private var visibleRecentActivity: [String] {
        let presentation = logPresentation
        return game.log.suffix(3).map { presentation.visibleLine(from: $0) }
    }

    private var recentActivityView: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("刚刚发生", systemImage: "waveform.path")
                .font(.subheadline.weight(.bold)).foregroundStyle(.orange)
            ForEach(Array(visibleRecentActivity.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: activitySymbol(for: line)).font(.caption.weight(.bold)).frame(width: 16)
                        .foregroundStyle(index == visibleRecentActivity.count - 1 ? .orange : .white.opacity(0.68))
                    Text(line).font(.system(size: 14, weight: index == visibleRecentActivity.count - 1 ? .semibold : .medium))
                        .foregroundStyle(index == visibleRecentActivity.count - 1 ? .white : .white.opacity(0.76))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
    }

    private var historyScrollView: some View {
        let presentation = logPresentation
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(game.log.indices, id: \.self) { index in
                        let line = presentation.visibleLine(from: game.log[index])
                        Text(line).font(.system(size: 13, weight: index == game.log.count - 1 ? .semibold : .regular))
                            .foregroundStyle(index == game.log.count - 1 ? .orange : .white.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .id(index)
                    }
                }
            }
            .onChange(of: game.log.count) { _, count in scrollHistory(proxy, to: count) }
            .onAppear { scrollHistory(proxy, to: game.log.count) }
            .animation(.easeOut(duration: 0.24), value: game.log.count)
        }
    }

    private func scrollHistory(_ proxy: ScrollViewProxy, to count: Int) {
        guard count > 0 else { return }
        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(count - 1, anchor: .bottom) }
    }

    private func activitySymbol(for line: String) -> String {
        if line.contains("受到") || line.contains("阵亡") { return "heart.slash.fill" }
        if line.contains("摸") { return "square.stack.3d.up.fill" }
        if line.contains("响应") || line.contains("打出") { return "shield.lefthalf.filled" }
        if line.contains("使用") { return "hand.tap.fill" }
        if line.contains("判定") { return "sparkles" }
        if line.contains("轮到") { return "arrow.turn.down.right" }
        return "circle.fill"
    }

    private var selectedTargetCard: Card? {
        game.human.hand.first { card in
            card.id == selectedCardID && ([.slash, .dodge, .snatch, .dismantle, .duel, .collateral, .indulgence].contains(card.kind))
        }
    }

    private var handInteractionHint: String {
        if let selectedTargetCard { return "已选【\(selectedTargetCard.title)】；请点桌面上高亮的角色。" }
        return "悬停查看作用；拖动调整顺序（或右键打开移动菜单）；点击选择，需要目标时再点桌面上高亮的角色。"
    }

    private var canRespondWithDodge: Bool {
        game.human.hand.contains(where: { $0.kind == game.responseCardKind || (game.responseCardKind == .dodge && game.human.general == .zhaoYun && $0.kind == .slash) })
            || (game.responseCardKind == .dodge && game.human.equipment[.armor]?.kind == .eightTrigrams)
    }

    private var responseButtonTitle: String {
        if game.responseCardKind == .dodge && game.human.equipment[.armor]?.kind == .eightTrigrams { return "打闪 / 八卦判定" }
        return "打出\(game.responseCardKind.title)"
    }

    private var phaseHint: String {
        switch game.phase {
        case .drawing: "摸牌阶段：点右下角摸两张牌。"
        case .action: "出牌阶段：使用基本牌、锦囊或装备。选中需要目标的牌后，点一名角色。"
        case .choosingHarvest(let playerID): "五谷丰登：轮到\(game.players[playerID].name)选择一张亮出的牌。"
        case let .choosingTargetCard(_, targetID, kind): "\(kind.title)：选择\(game.players[targetID].general.title)区域中的一张手牌、装备或判定牌。"
        case let .choosingCollateralTarget(_, weaponOwnerID): "借刀杀人：选择\(game.players[weaponOwnerID].general.title)攻击范围内的一名角色。"
        case let .awaitingCollateralSlash(_, weaponOwnerID, targetID): "\(game.players[weaponOwnerID].general.title)需对\(game.players[targetID].general.title)使用杀，否则交出武器。"
        case let .awaitingDoubleSwordChoice(_, targetID): "雌雄双股剑：\(game.players[targetID].general.title)可弃一张手牌；否则攻击者摸一张。"
        case let .awaitingIceSwordChoice(_, targetID): "寒冰剑：可防止杀的伤害，改为弃置\(game.players[targetID].general.title)至多两张手牌或装备。"
        case let .choosingIceSwordCard(_, targetID, remaining): "寒冰剑：选择\(game.players[targetID].general.title)的牌，还需选择\(remaining)张。"
        case let .awaitingAxeChoice(_, targetID): "贯石斧：杀被闪避。可弃两张其他牌强制命中\(game.players[targetID].general.title)。"
        case let .choosingAxeCosts(_, targetID, selectedIDs): "贯石斧：选择两张牌弃置，令对\(game.players[targetID].general.title)的杀命中（已选\(selectedIDs.count)/2）。"
        case let .awaitingKylinBowChoice(_, targetID): "麒麟弓：杀命中后，可弃置\(game.players[targetID].general.title)装备区的一匹马。"
        case let .choosingKylinBowHorse(_, targetID): "麒麟弓：选择弃置\(game.players[targetID].general.title)装备区的一匹马。"
        case let .choosingSpearCosts(selectedIDs): "丈八蛇矛：选择两张手牌当杀（已选\(selectedIDs.count)/2）。"
        case .choosingSpearTarget: "丈八蛇矛：点击一名合法角色，将两张手牌当杀使用。"
        case .awaitingDodge: "响应阶段：可以打出【\(game.responseCardKind.title)】，或承受伤害。"
        case .respondingToTrick: "无懈可击响应：可打出【无懈可击】抵消锦囊，也可以放弃响应。"
        case .awaitingDuelSlash: "决斗响应：双方轮流打出【杀】；无法响应的一方受到 1 点伤害。"
        case .dying: "濒死阶段：按顺序询问是否使用桃救援。"
        case .gameOver: winnerMessage
        }
    }

    private var winnerMessage: String {
        switch game.winner {
        case .lordAndLoyalist: "主公与忠臣获胜。天下已定。"
        case .rebels: "反贼获胜。主公已阵亡。"
        case .spy: "内奸获胜。成为最后的生还者。"
        case nil: "继续游戏。"
        }
    }

    private func select(_ card: Card) {
        guard game.currentPlayerID == 0, game.phase == .action else { return }
        selectedCardID = card.id
        switch card.kind {
        case .peach, .wine, .lightning, .barbarianInvasion, .arrows, .harvest,
             .godSalvation, .nullification, .amazingGrace, .offensiveHorse, .defensiveHorse,
             .eightTrigrams, .blackShield, .doubleSword, .iceSword, .greenDragonBlade,
             .QinggangSword, .serpentSpear, .kylinBow, .crossbow, .axe, .halberd:
            playSelected(on: nil)
        case .slash: break
        case .dodge:
            if game.human.general == .zhaoYun { break }
            message = "闪用于响应别人对你使用的杀。"
        case .snatch, .dismantle, .duel, .collateral, .indulgence: break
        }
    }

    private func playSelected(on target: Int?) {
        guard let id = selectedCardID else { return }
        run { try game.play(cardID: id, targetID: target) }
        selectedCardID = nil
        startAIPlayback()
    }

    private func respondToSlash(useDodge: Bool) {
        run { try game.respondToSlash(withDodge: useDodge) }
        game.continueAfterHumanResponse()
        startAIPlayback()
    }

    private func respondToTrick(useNullification: Bool) {
        run { try game.respondToTrick(withNullification: useNullification) }
        startAIPlayback()
    }

    private func respondToDuel(useSlash: Bool) {
        run { try game.respondToDuel(withSlash: useSlash) }
        startAIPlayback()
    }

    private func respondToDying(usePeach: Bool) {
        run { try game.respondToDying(withPeach: usePeach) }
        startAIPlayback()
    }

    private func finishTurn() {
        selectedCardID = nil
        run { try game.endTurn() }
        startAIPlayback()
    }

    private func startAIPlayback() {
        guard !isAIPlaying else { return }
        isAIPlaying = true
        aiTask = Task { @MainActor in
            while !Task.isCancelled {
                await voicePlayer.waitUntilIdle()
                guard !Task.isCancelled else { break }
                let oldLogCount = game.log.count
                guard game.advanceAI() else { break }
                enqueueCardVoices(since: oldLogCount)
                await voicePlayer.waitUntilIdle()
                try? await Task.sleep(for: .milliseconds(520))
            }
            isAIPlaying = false
        }
    }

    private func newGame(role: Role?, general: General?, playerCount: Int? = nil) {
        aiTask?.cancel()
        voicePlayer.stop()
        isAIPlaying = false
        selectedRole = role
        selectedGeneral = general
        if let playerCount { selectedPlayerCount = playerCount }
        game = GameEngine.newGame(humanGeneral: general, humanRole: role, generalPool: General.allCases, playerCount: selectedPlayerCount)
        selectedCardID = nil
        message = nil
    }

    private var objectiveText: String {
        switch game.human.role {
        case .lord: "消灭反贼和内奸。忠臣会帮助你，但开局身份保密。"
        case .loyalist: "保护主公，和主公一起消灭反贼与内奸。"
        case .rebel: "找到主公并击败他；主公阵亡时反贼获胜。"
        case .spy: "先观察局势，逐步削弱各方，最后成为唯一生还者。"
        }
    }

    private func run(_ action: () throws -> Void) {
        let oldLogCount = game.log.count
        do {
            try action()
            enqueueCardVoices(since: oldLogCount)
        } catch {
            message = errorMessage(error)
        }
    }

    private func enqueueCardVoices(since logIndex: Int) {
        let events = Array(game.log.dropFirst(min(logIndex, game.log.count)))
        voicePlayer.onSpeakingChanged = { isVoiceSpeaking = $0 }
        voicePlayer.enqueue(GameVoiceCue.spokenLines(from: events, players: game.players))
    }

    private func errorMessage(_ error: Error) -> String {
        switch error as? GameError {
        case .slashAlreadyUsed: "本回合不能再使用杀；张飞或装备诸葛连弩时可以连续使用。"
        case .outOfRange: "该角色不在这张牌的目标范围内。"
        case .invalidTarget: "这张牌现在不能对该角色使用。"
        case .invalidCard: "这张牌不能在出牌阶段直接使用。"
        case .missingCard: "这张手牌已经不在手中了。"
        default: "当前阶段不能这样操作。"
        }
    }

    private func winnerTitle(_ winner: WinningSide) -> String {
        switch winner {
        case .lordAndLoyalist: "主公阵营获胜"
        case .rebels: "反贼获胜"
        case .spy: "内奸获胜"
        }
    }

    private func cardSubtitle(_ kind: CardKind) -> String {
        switch kind {
        case .slash: "选中后点目标"
        case .dodge: "响应杀"
        case .peach: "回复体力"
        case .wine: "下一杀伤害 +1"
        default: kind.category.title
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title).font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 3)
            .background(color.opacity(0.2), in: Capsule()).foregroundStyle(color)
    }
}

private struct HandCardDropDelegate: DropDelegate {
    let targetID: Int
    @Binding var orderedIDs: [Int]
    @Binding var draggedID: Int?
    let reduceMotion: Bool

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != targetID else { return }
        let reordered = HandOrder.moving(draggedID, before: targetID, in: orderedIDs)
        guard reordered != orderedIDs else { return }
        if reduceMotion { orderedIDs = reordered }
        else { withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) { orderedIDs = reordered } }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

private struct LaunchWindowMaximizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { MaximizingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class MaximizingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window, !window.isZoomed else { return }
            window.zoom(nil)
        }
    }
}

private struct CardIllustrationView: View {
    let index: Int
    private let columns = 6

    private var artwork: Image? {
        let url = Bundle.main.url(forResource: "CardArt", withExtension: "png")
            ?? Bundle.module.url(forResource: "CardArt", withExtension: "png")
        guard let url,
              let image = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: image)
    }

    var body: some View {
        GeometryReader { geometry in
            if let artwork {
                artwork.resizable()
                    .frame(width: geometry.size.width * CGFloat(columns), height: geometry.size.height * 5)
                    .position(
                        x: geometry.size.width * (CGFloat(columns) / 2 - CGFloat(index % columns)),
                        y: geometry.size.height * (2.5 - CGFloat(index / columns))
                    )
            }
        }
        .clipped()
    }
}
