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
        .sheet(isPresented: $showRules) { RulesView().frame(minWidth: 620, minHeight: 620) }
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
        let canTarget = selectedTargetCard.map { game.phase == .action && game.canTarget(id, with: $0.kind, from: 0) } ?? false
        let isRecentAction = game.log.suffix(3).contains { $0.contains(player.name) }
        let isDamaged = damagedPlayers.contains(id)
        return Button { if canTarget { playSelected(on: id) } } label: {
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
                else if canTarget { Text("攻击").font(.caption.weight(.bold)).foregroundStyle(.orange) }
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
            Group {
                if case let .choosingHarvest(playerID) = game.phase, playerID == 0 {
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
                                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: game.human.hand.map(\.id))
                            }
                            .scrollIndicators(.hidden)
                            .padding(.vertical, 8)
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

    private func cardButton(_ card: Card) -> some View {
        let chosen = selectedCardID == card.id
        let hovering = hoveredCardID == card.id
        return Button { select(card) } label: {
            cardFace(card, chosen: chosen || hovering, isHarvest: false)
                .scaleEffect(hovering ? 1.07 : 1)
                .offset(y: hovering || chosen ? -6 : 0)
                .shadow(color: hovering || chosen ? .orange.opacity(0.38) : .clear, radius: hovering ? 14 : 9, y: 5)
                .zIndex(hovering ? 2 : 0)
        }
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.75)).combined(with: .opacity), removal: .scale(scale: 0.85).combined(with: .opacity)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(.plain).help(card.kind.tooltipText)
        .disabled(isVoiceSpeaking || isAIPlaying || game.currentPlayerID != 0 || game.phase != .action)
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
        .accessibilityHint("点击选择；拖动可调整手牌顺序，也可打开操作菜单移动。需要目标时再点桌面上高亮的角色。")
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
            }
            .scrollIndicators(.hidden).padding(.vertical, 8).frame(height: 222)
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
            cardFace(card, chosen: hovering, isHarvest: true)
                .scaleEffect(hovering ? 1.07 : 1)
                .offset(y: hovering ? -6 : 0)
                .shadow(color: hovering ? .orange.opacity(0.38) : .clear, radius: 14, y: 5)
                .zIndex(hovering ? 2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hoveredCardID = $0 ? card.id : nil }
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: hovering)
        .help(card.kind.tooltipText)
        .disabled(isVoiceSpeaking || isAIPlaying)
        .accessibilityIdentifier("harvest-choice-\(card.id)")
    }

    private func cardFace(_ card: Card, chosen: Bool, isHarvest: Bool) -> some View {
        VStack(spacing: 5) {
            CardIllustrationView(index: card.kind.illustrationIndex)
                .frame(width: 112, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
            Text(card.title)
                .font(.system(size: card.title.count > 5 ? 14 : 19, weight: .bold, design: .serif))
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(card.category.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
        }
        .frame(width: 142, height: 184)
        .foregroundStyle(isHarvest ? Color.black : card.kind == .dodge ? Color.blue : card.kind == .peach ? Color.red : Color.black)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.94, green: 0.91, blue: 0.82)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(chosen ? .orange : .white.opacity(0.5), lineWidth: chosen ? 2.5 : 1))
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
                Text("悬停在任意手牌上，可查看这张牌的作用。")
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
                Button { finishTurn() } label: { Label("结束回合", systemImage: "arrow.right.circle.fill") }
                    .buttonStyle(.borderedProminent).tint(Color(red: 0.65, green: 0.31, blue: 0.18)).controlSize(.large)
            case .choosingHarvest, .awaitingDodge, .awaitingDuelSlash, .respondingToTrick, .dying, .gameOver: EmptyView()
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

    private var visibleLog: [String] {
        GameLogPresentation.visibleLines(from: game.log, players: game.players)
    }

    private var visibleRecentActivity: [String] { Array(visibleLog.suffix(3)) }

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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(visibleLog.enumerated()), id: \.offset) { index, line in
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

private struct RulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("第一次玩？从这里开始").font(.system(size: 26, weight: .bold, design: .serif))
                Text("你可以选择或随机获得身份和武将。支持 4–8 人身份局，主公、忠臣、反贼、内奸的人数会随局人数变化；主公身份公开，其余身份隐藏。观察谁在攻击谁，推理阵营。")
                ruleSection("胜利目标", "主公和忠臣：消灭反贼与内奸。反贼：杀死主公。内奸：除掉其他人，最后亲手成为唯一生还者。")
                ruleSection("每回合怎么走", "1. 摸两张牌。  2. 使用手牌。  3. 手牌多于当前体力时，弃到相同数量。然后轮到下一名存活角色。电脑行动会逐步播放，战报会保留并自动滚到最新行动。")
                ruleSection("基本牌", "杀：攻击攻击范围内角色。每回合通常一张；张飞与诸葛连弩可连续使用。目标可以打闪响应。\n\n闪：响应杀。赵云可以用杀当闪。\n\n桃：出牌阶段回复自己 1 点体力，也能在濒死时救援。标准牌堆不含酒。")
                ruleSection("锦囊与装备", "标准牌堆包含过河拆桥、顺手牵羊、决斗、南蛮入侵、万箭齐发、桃园结义、无中生有等锦囊，以及武器、防具和进攻马/防御马。选中牌后按提示选目标；装备会放到角色牌旁的装备区，并替换同类装备。")
                ruleSection("武将与技能", "可选标准版 25 名武将，也可随机抽取；同一局不会重复。武将拥有不同的体力上限和技能，技能说明常驻显示在右侧。目前部分技能效果还在实现中。")
                ruleSection("怎样判断身份", "反贼通常会攻击主公。忠臣会帮助主公，但也可能暂时不暴露身份。内奸需要控制局势，避免过早成为众矢之的。看行动和出牌，不要只看一次攻击。")
                ruleSection("牌堆与装备", "标准牌堆共 108 张，含基本牌 53 张、锦囊牌 36 张、装备牌 19 张；每张牌都有标准花色和点数。武器调整攻击范围，进攻马与防御马调整距离。需要打闪时，八卦阵翻开牌堆顶一张牌：红色视为闪并抵消攻击，黑色判定失败并受到伤害；翻出的判定牌会进入弃牌堆。")
                ruleSection("身份局人数", "4 人：1 主、1 忠、1 反、1 内。5 人：1 主、1 忠、2 反、1 内。6 人：1 主、1 忠、3 反、1 内。7 人：1 主、2 忠、3 反、1 内。8 人：1 主、2 忠、4 反、1 内。")
                ruleSection("当前规则边界", "目前仍有规则缺口：闪电与乐不思蜀没有按牌面判定结算；多目标锦囊的无懈可击没有逐目标开窗；借刀杀人没有完整的出杀/交刀流程；多数武将技能和多种武器、防具特效尚未实现。详细清单见项目 README。")
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
        .background(Color(red: 0.95, green: 0.92, blue: 0.84)).preferredColorScheme(.light)
    }

    private func ruleSection(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Color(red: 0.43, green: 0.20, blue: 0.12))
            Text(detail).fixedSize(horizontal: false, vertical: true)
        }
    }
}
