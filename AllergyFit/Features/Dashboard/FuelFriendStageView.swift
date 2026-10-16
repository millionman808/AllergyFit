import SwiftUI

/// FuelFriendStageView — The Living Interactive Companion Stage
/// Implements Meta Pattern 1 (The Human Pattern), Meta Pattern 2 (Behavior Stakes),
/// and Meta Pattern 3 (The Craft Pattern).
/// Features hardware-accelerated transparent HEVC video animation loops (idle, celebrate, eat, drink),
/// physical puppet fallback, and unlockable Food Pals companion roster.
struct FuelFriendStageView: View {
    @ObservedObject var friendStore: FuelFriendStore
    let calories: Int
    let targetCalories: Int
    let protein: Int
    let targetProtein: Int
    let water: Int
    let waterGoal: Int
    let mealCount: Int
    let allergens: [String]

    enum CompanionAction: String, CaseIterable {
        case idle = "idle_alpha"
        case celebrate = "celebrate_alpha"
        case eat = "eat_alpha"
        case drink = "drink_alpha"
    }

    @State private var currentAction: CompanionAction = .idle
    @State private var actionTimer: Task<Void, Never>? = nil
    @State private var usePuppetFallback = false
    @State private var showPalsSheet = false
    @State private var showShopSheet = false
    @State private var showPostcardModal = false
    @State private var showScrapbookSheet = false
    @State private var shopTab: PipGardenShopSheet.Tab = .pots
    @State private var showRenameAlert = false
    @State private var tempName = ""

    /// Blink / tilt / tap loops. Kept so leaving Today stops them; otherwise
    /// every visit stacked another set and Pip got twitchier each time.
    @State private var idleTimers: [Timer] = []

    // Organic animation state (used by puppet & floating particles)
    @State private var isBreathing = false
    @State private var wingFlap = false
    @State private var footTap = false
    @State private var isBlinking = false
    @State private var isHappySquint = false
    @State private var headTilt: Double = 0
    @State private var jumpOffset: CGFloat = 0
    @State private var petWingFlurry = false
    @State private var floatingHearts: [HeartParticle] = []

    struct HeartParticle: Identifiable {
        let id = UUID()
        var xOffset: CGFloat
        var yOffset: CGFloat
        var opacity: Double
        var scale: CGFloat
    }

    private var mood: FuelFriendStore.Mood {
        friendStore.currentMood(
            calories: calories,
            targetCalories: targetCalories,
            protein: protein,
            targetProtein: targetProtein,
            water: water,
            waterGoal: waterGoal
        )
    }

    private var dialogueText: String {
        friendStore.dialogue(
            calories: calories,
            targetCalories: targetCalories,
            protein: protein,
            targetProtein: targetProtein,
            water: water,
            waterGoal: waterGoal,
            mealCount: mealCount,
            allergens: allergens
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Speech Bubble
            speechBubble

            // MARK: - Interactive Character Stage
            stageGraphic
                .frame(height: 160)
                .padding(.top, 2)

            // MARK: - Name & Mood Pill + Pals Shortcut
            companionBar

            // MARK: - Quick Interaction Chips
            actionChipsRow
                .padding(.vertical, 2)

            // MARK: - Companion Care Meters (Meta Pattern 2: The Behavior Stakes)
            careMetersRow
                .padding(.top, 4)

            // MARK: - Pip's Daily Adventure Banner
            adventureBanner
                .padding(.top, 2)
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.surface,
                            Theme.Colors.surfaceRaised.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.Colors.parchmentBorder.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 14, y: 5)
        )
        .sheet(isPresented: $showShopSheet) {
            PipGardenShopSheet(friendStore: friendStore, initialTab: shopTab)
        }
        .sheet(isPresented: $showPalsSheet) {
            PipGardenShopSheet(friendStore: friendStore, initialTab: .pals)
        }
        .sheet(isPresented: $showPostcardModal) {
            AdventurePostcardModal(friendStore: friendStore)
        }
        .sheet(isPresented: $showScrapbookSheet) {
            PostcardScrapbookSheet(friendStore: friendStore)
        }
        .onAppear {
            startCompanionAnimations()

            let testAction = friendStore.activeAction
            if testAction == "celebrate" {
                playAction(.celebrate, duration: 25.0)
            } else if testAction == "eat" {
                playAction(.eat, duration: 25.0)
            } else if testAction == "drink" {
                playAction(.drink, duration: 25.0)
            } else if testAction == "puppet" {
                usePuppetFallback = true
            }

            let args = ProcessInfo.processInfo.arguments
            if args.contains("-showShop") || UserDefaults.standard.bool(forKey: "showShop") {
                shopTab = .pots
                showShopSheet = true
            } else if args.contains("-showPals") || UserDefaults.standard.bool(forKey: "showPals") {
                shopTab = .pals
                showShopSheet = true
            } else if args.contains("-showPostcard") || UserDefaults.standard.bool(forKey: "showPostcard") {
                showPostcardModal = true
            } else if args.contains("-showScrapbook") || UserDefaults.standard.bool(forKey: "showScrapbook") {
                showScrapbookSheet = true
            }
        }
        .onChange(of: friendStore.activeAction) { newAction in
            switch newAction {
            case "celebrate":
                playAction(.celebrate, duration: 5.0)
            case "eat":
                playAction(.eat, duration: 5.0)
            case "drink":
                playAction(.drink, duration: 5.0)
            case "idle":
                withAnimation(.easeInOut(duration: 0.35)) {
                    currentAction = .idle
                    isHappySquint = false
                }
            case "puppet":
                usePuppetFallback = true
            default:
                break
            }
        }
        .onDisappear { stopCompanionAnimations() }
        .alert("Name your Fuel Friend", isPresented: $showRenameAlert) {
            TextField("Name", text: $tempName)
            Button("Save") {
                let trimmed = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { friendStore.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Speech Bubble
    private var speechBubble: some View {
        HStack {
            Text(dialogueText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(3)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                )
        }
        .animation(.spring(response: 0.4), value: dialogueText)
    }

    // MARK: - Interactive Character Stage Graphic
    @ViewBuilder
    private var stageGraphic: some View {
        ZStack {
            // Windowsill Plant Pot & Decor accompaniment
            HStack(alignment: .bottom) {
                if !friendStore.equippedDecor.isEmpty {
                    WindowsillDecorView(decorId: friendStore.equippedDecor)
                        .offset(x: 4, y: 46)
                }
                Spacer()
                Image(friendStore.pot)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
                    .offset(x: -6, y: 44)
            }
            .frame(width: 220)

            // Ground contact shadow (used for puppet mode)
            if usePuppetFallback {
                Image("PipShadow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 26)
                    .scaleEffect(jumpOffset < 0 ? 0.82 : (isBreathing ? 1.04 : 0.96))
                    .opacity(jumpOffset < 0 ? 0.40 : 0.82)
                    .offset(y: 74)
            }

            // Companion Render Layer
            if friendStore.activeAction == "bloated" {
                Image("pip_bloated")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 175, height: 175)
                    .transition(.scale.combined(with: .opacity))
            } else if usePuppetFallback {
                companionPuppet
            } else {
                let isTesting = ProcessInfo.processInfo.arguments.contains("-testCompanionAction")
                    || (UserDefaults.standard.string(forKey: "testCompanionAction") != nil && !UserDefaults.standard.string(forKey: "testCompanionAction")!.isEmpty)
                LoopingAlphaPlayerView(
                    videoName: currentAction.rawValue,
                    isLooping: currentAction == .idle || isTesting,
                    onFinished: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentAction = .idle
                            friendStore.activeAction = "idle"
                        }
                    }
                )
                .id(currentAction.rawValue)
                .frame(width: 175, height: 175)
            }

            // Floating Hearts Micro-Interaction
            ForEach(floatingHearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.Colors.finchRose)
                    .scaleEffect(heart.scale)
                    .opacity(heart.opacity)
                    .offset(x: heart.xOffset, y: heart.yOffset)
            }
        }
        .offset(y: jumpOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            triggerPet()
        }
    }

    // MARK: - Name & Mood Pill Bar
    private var companionBar: some View {
        HStack(spacing: 8) {
            Button {
                tempName = friendStore.name
                showRenameAlert = true
            } label: {
                HStack(spacing: 4) {
                    Text(friendStore.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            Text("•")
                .foregroundStyle(Theme.Colors.textTertiary)

            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Level \(friendStore.level) · \(friendStore.growthStageTitle)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.Colors.finchMint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Theme.Colors.finchMint.opacity(0.12), in: Capsule())

            Spacer()

            // Seeds Counter (opens Garden Shop)
            Button {
                shopTab = .pots
                showShopSheet = true
                Haptics.tap()
            } label: {
                HStack(spacing: 4) {
                    Image("icon_seed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text("\(friendStore.seeds)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.surfaceRaised, in: Capsule())
            }
            .buttonStyle(.plain)

            if Config.foodPalsEnabled {
            Button {
                shopTab = .pals
                showShopSheet = true
                Haptics.tap()
            } label: {
                HStack(spacing: 4) {
                    Text("Pals")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.finchMint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.finchMint.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Quick Interaction Chips Row
    private var actionChipsRow: some View {
        HStack(spacing: 5) {
            quickActionChip(
                icon: "sparkles",
                label: "Pet",
                color: Theme.Colors.finchMint,
                isActive: currentAction == .celebrate
            ) {
                triggerPet()
            }

            quickActionChip(
                icon: "fork.knife",
                label: "Snack",
                color: Theme.Colors.finchPeach,
                isActive: currentAction == .eat
            ) {
                triggerFeed()
            }

            quickActionChip(
                icon: "drop.fill",
                label: "Hydrate",
                color: Theme.Colors.finchSky,
                isActive: currentAction == .drink
            ) {
                triggerHydrate()
            }

            quickActionChip(
                icon: "leaf.fill",
                label: "Tummy",
                color: Theme.Colors.finchLavender,
                isActive: friendStore.activeAction == "bloated"
            ) {
                friendStore.triggerBloatedReaction()
            }

        }
    }

    // MARK: - Care Meters Row
    private var careMetersRow: some View {
        HStack(spacing: 8) {
            careMeter(
                title: "Hunger",
                icon: "fork.knife",
                progress: targetCalories > 0 ? min(Double(calories) / Double(targetCalories), 1.0) : 0,
                color: Theme.Colors.finchPeach
            )

            careMeter(
                title: "Water",
                icon: "drop.fill",
                progress: waterGoal > 0 ? min(Double(water) / Double(waterGoal), 1.0) : 0,
                color: Theme.Colors.finchSky
            )

            careMeter(
                title: "Energy",
                icon: "bolt.fill",
                progress: friendStore.energy / 100,
                color: Theme.Colors.finchButter
            )
        }
    }

    // MARK: - Finch-Style Daily Adventure Banner
    /// Goals fill energy; full energy unlocks an adventure; Pip is away for a
    /// minute and a half, then a letter arrives. One adventure a day.
    private var adventureBanner: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            adventureBannerContent(now: context.date)
        }
    }

    private func adventureBannerContent(now: Date) -> some View {
        let state = friendStore.adventureState
        let secondsLeft = friendStore.adventureSecondsLeft(at: now)
        let isAway = state == "exploring" && secondsLeft > 0
        let letterReady = state == "exploring" && secondsLeft == 0
        let isCompleted = state == "completed_today"
        let canGo = friendStore.canStartAdventure

        let tint: Color = letterReady ? Theme.Colors.finchPeach
            : isCompleted ? Theme.Colors.finchLavender
            : isAway ? Theme.Colors.finchSky : Theme.Colors.finchMint
        let icon = letterReady ? "envelope.fill" : isCompleted ? "photo.on.rectangle.angled"
            : isAway ? "figure.hiking" : "map.fill"
        let title = letterReady ? "A letter from \(friendStore.name)!"
            : isCompleted ? "Adventure done for today"
            : isAway ? "\(friendStore.name) is exploring"
            : canGo ? "Adventure ready!" : "Today's adventure"
        let detail = letterReady ? "Back from \(friendStore.currentPostcard.destination)"
            : isCompleted ? "\(friendStore.collectedPostcards.count) of \(FuelFriendStore.allDestinations.count) postcards collected"
            : isAway ? "Back in \(secondsLeft / 60):\(String(format: "%02d", secondsLeft % 60))"
            : canGo ? "\(friendStore.name) has the energy to go exploring"
            : "Fill \(friendStore.name)'s energy with today's goals"

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if letterReady {
                bannerButton("Read", color: Theme.Colors.finchPeach) {
                    showPostcardModal = true
                    Haptics.success()
                }
            } else if isCompleted {
                bannerButton("Postcards", color: Theme.Colors.finchLavender, filled: false) {
                    showScrapbookSheet = true
                    Haptics.tap()
                }
            } else if canGo {
                bannerButton("Explore", color: Theme.Colors.finchMint) {
                    friendStore.startAdventure()
                }
            } else if !isAway {
                Text("\(Int(friendStore.energy))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.Colors.surfaceRaised.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.Colors.parchmentBorder.opacity(0.7), lineWidth: 1)
                )
        )
    }

    private func bannerButton(_ label: String, color: Color, filled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(filled ? Color.white : color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(filled ? color : color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Playback Controller
    private func playAction(_ action: CompanionAction, duration: Double) {
        actionTimer?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            currentAction = action
            if action == .celebrate {
                jumpOffset = -18
                isHappySquint = true
            }
        }

        if action == .celebrate {
            Haptics.success()
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                    spawnHeart()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    jumpOffset = 0
                }
            }
        } else {
            Haptics.tap()
        }

        let isTesting = ProcessInfo.processInfo.arguments.contains("-testCompanionAction")
            || (UserDefaults.standard.string(forKey: "testCompanionAction") != nil && !UserDefaults.standard.string(forKey: "testCompanionAction")!.isEmpty)
        if isTesting { return }

        actionTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentAction = .idle
                        isHappySquint = false
                    }
                }
            }
        }
    }

    private func triggerPet() {
        friendStore.pet()
        playAction(.celebrate, duration: 4.8)
    }

    private func triggerFeed() {
        friendStore.feed(mealName: "Macro-Clean Bowl")
        playAction(.eat, duration: 5.0)
    }

    private func triggerHydrate() {
        friendStore.hydrate()
        playAction(.drink, duration: 5.0)
    }

    // MARK: - Quick Action Chip Component
    private func quickActionChip(
        icon: String,
        label: String,
        color: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isActive ? Color.white : color)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                isActive
                    ? color
                    : color.opacity(0.12),
                in: Capsule()
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.25), value: isActive)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Deconstructed & Reconstructed Animated Puppet
    private var companionPuppet: some View {
        ZStack {
            // 1. Feet
            HStack(spacing: 28) {
                Image("PipFootLeft")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 30)
                    .offset(y: footTap ? -3 : 0)

                Image("PipFootRight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 30)
                    .offset(y: footTap ? 0 : -3)
            }
            .offset(y: 70)

            // 2. Arms
            Image("PipWingLeft")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 52)
                .rotationEffect(
                    .degrees(petWingFlurry ? -38 : (wingFlap ? -8 : 6)),
                    anchor: UnitPoint(x: 0.85, y: 0.15)
                )
                .offset(x: -52, y: -2)

            Image("PipWingRight")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 52)
                .rotationEffect(
                    .degrees(petWingFlurry ? 38 : (wingFlap ? 8 : -6)),
                    anchor: UnitPoint(x: 0.15, y: 0.15)
                )
                .offset(x: 52, y: -2)

            // 3. Central Body
            Image("PipBody")
                .resizable()
                .scaledToFit()
                .frame(width: 98, height: 134)
                .scaleEffect(x: isBreathing ? 1.02 : 0.985, y: isBreathing ? 0.985 : 1.02, anchor: .bottom)
                .rotationEffect(.degrees(headTilt))
                .shadow(color: Theme.Colors.finchMint.opacity(0.16), radius: 10, y: 4)

            // 4. Expressive Eyelids
            Image("PipEyelids")
                .resizable()
                .scaledToFit()
                .frame(width: 98, height: 134)
                .scaleEffect(x: isBreathing ? 1.02 : 0.985, y: isBreathing ? 0.985 : 1.02, anchor: .bottom)
                .rotationEffect(.degrees(headTilt))
                .opacity((isBlinking || isHappySquint) ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.12), value: isBlinking)
                .animation(.spring(response: 0.25), value: isHappySquint)

            // 5. Floating Mood Badge
            moodAccessory
                .offset(x: 36, y: -45)
                .scaleEffect(isBreathing ? 1.05 : 0.95)
        }
    }

    @ViewBuilder
    private var moodAccessory: some View {
        switch mood {
        case .hungry:
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Colors.finchPeach)
                .background(Circle().fill(Color.white).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2))
        case .hydrated:
            Image(systemName: "drop.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.Colors.finchSky)
                .background(Circle().fill(Color.white).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2))
        case .strong:
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.onVolt)
                .padding(6)
                .background(Circle().fill(Theme.Colors.finchMint).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2))
        case .sleepy:
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Colors.finchLavender)
                .background(Circle().fill(Color.white).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2))
        default:
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Colors.finchButter)
                .padding(6)
                .background(Circle().fill(Color.white).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2))
        }
    }

    // MARK: - Care Meter Pill
    private func careMeter(title: String, icon: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surfaceRaised)
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * CGFloat(progress), 6))
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Theme.Colors.surfaceRaised.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private func spawnHeart() {
        let heart = HeartParticle(
            xOffset: CGFloat.random(in: -36...36),
            yOffset: -10,
            opacity: 1.0,
            scale: CGFloat.random(in: 0.9...1.2)
        )
        floatingHearts.append(heart)

        withAnimation(.easeOut(duration: 1.1)) {
            if let index = floatingHearts.firstIndex(where: { $0.id == heart.id }) {
                floatingHearts[index].yOffset = -85 - CGFloat.random(in: 0...20)
                floatingHearts[index].opacity = 0
                floatingHearts[index].scale = 1.4
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            floatingHearts.removeAll(where: { $0.id == heart.id })
        }
    }

    private func startCompanionAnimations() {
        withAnimation(
            .easeInOut(duration: 1.9)
            .repeatForever(autoreverses: true)
        ) {
            isBreathing = true
        }

        withAnimation(
            .easeInOut(duration: 2.3)
            .repeatForever(autoreverses: true)
        ) {
            wingFlap = true
        }

        stopCompanionAnimations()
        let tap = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                footTap.toggle()
            }
        }

        let tilt = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                headTilt = Double.random(in: -3.5...3.5)
            }
        }

        let blink = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            guard !isHappySquint else { return }
            withAnimation(.easeInOut(duration: 0.1)) {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isBlinking = false
                }
            }
        }
        idleTimers = [tap, tilt, blink]
    }

    private func stopCompanionAnimations() {
        idleTimers.forEach { $0.invalidate() }
        idleTimers = []
    }
}

// MARK: - Food Pals Unlock & Showcase Sheet
struct FoodPalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var friendStore: FuelFriendStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Banner
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Food & Nutrition Companions")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Build consistent safe eating streaks to unlock new nutrient pals with special motivational perks.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 4)

                    // Companions Grid
                    VStack(spacing: 12) {
                        ForEach(friendStore.availableCompanions) { pal in
                            companionCard(pal)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Food Pals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.finchMint)
                }
            }
        }
    }

    private func companionCard(_ pal: FuelFriendStore.FoodCompanion) -> some View {
        let isSelected = friendStore.selectedCompanionId == pal.id
        return HStack(spacing: 14) {
            // Pal Avatar
            ZStack {
                Circle()
                    .fill(pal.isUnlocked ? Theme.Colors.finchMint.opacity(0.18) : Theme.Colors.surfaceRaised)
                    .frame(width: 58, height: 58)
                Image(systemName: pal.icon)
                    .font(.system(size: 30))
                    .opacity(pal.isUnlocked ? 1.0 : 0.4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pal.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("• \(pal.foodType)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                    if isSelected {
                        Text("Active")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.finchMint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.finchMint.opacity(0.15), in: Capsule())
                    } else if !pal.isUnlocked {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                            Text("\(pal.unlockStreakDays)d streak")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.surfaceRaised, in: Capsule())
                    }
                }

                Text(pal.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .bold))
                    Text(pal.perk)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(pal.isUnlocked ? Theme.Colors.finchMint : Theme.Colors.textTertiary)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSelected ? Theme.Colors.finchMint.opacity(0.6) : Theme.Colors.parchmentBorder.opacity(0.7),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
        )
        .onTapGesture {
            if pal.isUnlocked {
                friendStore.selectedCompanionId = pal.id
                Haptics.success()
            } else {
                Haptics.tap()
            }
        }
    }
}

// MARK: - Pip's Windowsill Garden Shop & Customization Sheet
struct PipGardenShopSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var friendStore: FuelFriendStore
    var initialTab: Tab = .pots

    enum Tab: String, CaseIterable, Identifiable {
        case pots = "Pots"
        case decor = "Decor"
        case pals = "Pals"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .pots: return "leaf.fill"
            case .decor: return "sparkles"
            case .pals: return "heart.fill"
            }
        }
    }

    @State private var selectedTab: Tab = .pots
    @State private var showSeedsInfo = false
    @State private var notEnoughSeedsMessage: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    tabPicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    ScrollView {
                        VStack(spacing: 16) {
                            switch selectedTab {
                            case .pots:
                                potsGrid
                            case .decor:
                                decorGrid
                            case .pals:
                                palsList
                            }

                            seedEarningBanner
                                .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.finchMint)
                }
            }
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if let idx = args.firstIndex(of: "-testShopTab"), idx + 1 < args.count {
                    let tabName = args[idx + 1]
                    if tabName == "decor" { selectedTab = .decor }
                    else if tabName == "pals" && Config.foodPalsEnabled { selectedTab = .pals }
                    else { selectedTab = .pots }
                } else {
                    selectedTab = (initialTab == .pals && !Config.foodPalsEnabled) ? .pots : initialTab
                }
            }
            .sheet(isPresented: $showSeedsInfo) {
                SeedsInfoSheet()
            }
            .alert("Need More Seeds", isPresented: Binding(
                get: { notEnoughSeedsMessage != nil },
                set: { if !$0 { notEnoughSeedsMessage = nil } }
            )) {
                Button("Got it", role: .cancel) { notEnoughSeedsMessage = nil }
            } message: {
                Text(notEnoughSeedsMessage ?? "")
            }
        }
    }

    // MARK: - Header Section with Seeds Pill & Mascot Avatar
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.finchMint.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image("pip_happy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(friendStore.name)'s Garden Shop")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Cozy up your windowsill garden")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            // Seeds Counter Pill (tap for info)
            Button {
                showSeedsInfo = true
                Haptics.tap()
            } label: {
                HStack(spacing: 5) {
                    Image("icon_seed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                    Text("\(friendStore.seeds)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.surface, in: Capsule())
                .overlay(
                    Capsule().stroke(Theme.Colors.parchmentBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tab Segmented Picker
    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases.filter { $0 != .pals || Config.foodPalsEnabled }) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                    Haptics.tap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Theme.Colors.finchMint : Theme.Colors.surface)
                    )
                    .foregroundStyle(isSelected ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected ? Color.clear : Theme.Colors.parchmentBorder.opacity(0.8),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.02), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Flower Pots Grid
    private var potsGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(FuelFriendStore.allPots) { potItem in
                let isEquipped = friendStore.pot == potItem.id
                let isUnlocked = friendStore.isPotUnlocked(potItem.id)

                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: potItem.accentColorHex).opacity(0.12),
                                        Theme.Colors.surfaceRaised.opacity(0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 110)

                        Image(potItem.id)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 72)
                            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 4)

                        if isEquipped {
                            VStack {
                                HStack {
                                    Spacer()
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                        Text("Active")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(Theme.Colors.onVolt)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Theme.Colors.finchMint, in: Capsule())
                                    .padding(8)
                                }
                                Spacer()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(potItem.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(potItem.subtitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)

                    if isEquipped {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("On Windowsill")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Theme.Colors.finchMint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Theme.Colors.finchMint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else if isUnlocked {
                        Button {
                            friendStore.equipPot(potItem.id)
                        } label: {
                            Text("Equip Pot")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Theme.Colors.parchmentBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            if friendStore.seeds >= potItem.cost {
                                friendStore.buyAndEquipPot(potItem)
                            } else {
                                notEnoughSeedsMessage = "You have \(friendStore.seeds) seeds, but need \(potItem.cost) seeds for the \(potItem.name) pot. Log your meals or water today to earn more seeds!"
                                Haptics.warning()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image("icon_seed")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                Text("\(potItem.cost) Seeds")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Theme.Colors.onVolt)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    isEquipped ? Theme.Colors.finchMint.opacity(0.6) : Theme.Colors.parchmentBorder.opacity(0.8),
                                    lineWidth: isEquipped ? 1.5 : 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                )
            }
        }
    }

    // MARK: - Windowsill Decor Grid
    private var decorGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(FuelFriendStore.allDecor) { item in
                let isEquipped = friendStore.equippedDecor == item.id
                let isUnlocked = friendStore.isDecorUnlocked(item.id)

                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: item.tintHex).opacity(0.14),
                                        Theme.Colors.surfaceRaised.opacity(0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 110)

                        WindowsillDecorView(decorId: item.id)
                            .scaleEffect(1.3)

                        if isEquipped {
                            VStack {
                                HStack {
                                    Spacer()
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                        Text("Placed")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(Theme.Colors.onVolt)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Theme.Colors.finchMint, in: Capsule())
                                    .padding(8)
                                }
                                Spacer()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(item.subtitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)

                    if isEquipped {
                        Button {
                            friendStore.equipDecor(nil)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Remove")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else if isUnlocked {
                        Button {
                            friendStore.equipDecor(item.id)
                        } label: {
                            Text("Place on Sill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Theme.Colors.parchmentBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            if friendStore.seeds >= item.cost {
                                friendStore.buyAndEquipDecor(item)
                            } else {
                                notEnoughSeedsMessage = "You have \(friendStore.seeds) seeds, but need \(item.cost) seeds for the \(item.name). Log your meals or water today to earn more seeds!"
                                Haptics.warning()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image("icon_seed")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                Text("\(item.cost) Seeds")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Theme.Colors.onVolt)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Theme.Colors.volt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    isEquipped ? Theme.Colors.finchMint.opacity(0.6) : Theme.Colors.parchmentBorder.opacity(0.8),
                                    lineWidth: isEquipped ? 1.5 : 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                )
            }
        }
    }

    // MARK: - Food Pals List
    private var palsList: some View {
        VStack(spacing: 12) {
            ForEach(friendStore.availableCompanions) { pal in
                let isSelected = friendStore.selectedCompanionId == pal.id
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(pal.isUnlocked ? Theme.Colors.finchMint.opacity(0.18) : Theme.Colors.surfaceRaised)
                            .frame(width: 58, height: 58)
                        Image(systemName: pal.icon)
                            .font(.system(size: 30))
                            .opacity(pal.isUnlocked ? 1.0 : 0.4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(pal.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("• \(pal.foodType)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textTertiary)
                            Spacer()
                            if isSelected {
                                Text("Active")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.finchMint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Theme.Colors.finchMint.opacity(0.15), in: Capsule())
                            } else if !pal.isUnlocked {
                                HStack(spacing: 3) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9))
                                    Text("\(pal.unlockStreakDays)d streak")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Colors.surfaceRaised, in: Capsule())
                            }
                        }

                        Text(pal.description)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 9, weight: .bold))
                            Text(pal.perk)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(pal.isUnlocked ? Theme.Colors.finchMint : Theme.Colors.textTertiary)
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected ? Theme.Colors.finchMint.opacity(0.6) : Theme.Colors.parchmentBorder.opacity(0.7),
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                )
                .onTapGesture {
                    if pal.isUnlocked {
                        friendStore.selectedCompanionId = pal.id
                        Haptics.success()
                    }
                }
            }
        }
    }

    // MARK: - Seed Earning Info Banner
    private var seedEarningBanner: some View {
        HStack(spacing: 12) {
            Image("icon_seed")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("How to earn seeds")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Finish your daily goals to earn seeds. Every goal is worth \(FuelFriendStore.seedsPerGoal), and a full day earns a bonus.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Button {
                showSeedsInfo = true
                Haptics.tap()
            } label: {
                Text("Learn")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.finchMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.finchMint.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
                )
        )
    }
}

// MARK: - Windowsill Decor Visual Representation
struct WindowsillDecorView: View {
    let decorId: String

    var body: some View {
        if let item = FuelFriendStore.allDecor.first(where: { $0.id == decorId }) {
            ZStack {
                Circle()
                    .fill(Color(hex: item.tintHex).opacity(0.18))
                    .frame(width: 36, height: 36)
                    .blur(radius: 1)
                    .offset(y: 2)

                Image(systemName: item.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color(hex: item.tintHex))
                    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 2)
            }
            .frame(width: 44, height: 44)
        }
    }
}

// MARK: - Seeds Info Sheet
struct SeedsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("The Seeds of Self-Care")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Seeds represent the mindful energy and care you invest in your nutrition and body each day.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }

                        VStack(spacing: 12) {
                            seedRewardRow(
                                icon: "checkmark.circle.fill",
                                title: "Finish one of today's goals",
                                reward: "+\(FuelFriendStore.seedsPerGoal) seeds",
                                color: Theme.Colors.finchMint
                            )
                            seedRewardRow(
                                icon: "star.fill",
                                title: "Finish every goal in a day",
                                reward: "+\(FuelFriendStore.perfectDayBonus) bonus",
                                color: Theme.Colors.finchButter
                            )
                            seedRewardRow(
                                icon: "map.fill",
                                title: "Bring back an adventure postcard",
                                reward: "+30 seeds",
                                color: Theme.Colors.finchLavender
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("No Real Money. Ever.")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Seeds can never be purchased with real money. Every pot and windowsill decor item is earned purely through self-care habits and mindful choices.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.Colors.surfaceRaised)
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Seeds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.finchMint)
                }
            }
        }
    }

    private func seedRewardRow(icon: String, title: String, reward: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Text(reward)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.finchMint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.finchMint.opacity(0.12), in: Capsule())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
                )
        )
    }
}

// MARK: - Finch-Style Adventure Postcard Modal
struct AdventurePostcardModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var friendStore: FuelFriendStore
    @State private var selectedChoice: String? = nil

    private var postcard: FuelFriendStore.Postcard {
        friendStore.currentPostcard
    }

    private var accentColor: Color {
        Color(hex: postcard.accentColorHex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Airmail top accent bar
                        airmailBar

                        // Postcard Physical Canvas
                        postcardCanvas

                        // Pip's Reflection Question & Interactive Choices
                        reflectionCard

                        // Keep Postcard & Claim Rewards CTA
                        claimRewardsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Adventure Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }
        }
    }

    private var airmailBar: some View {
        HStack(spacing: 5) {
            ForEach(0..<20, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i % 2 == 0 ? Theme.Colors.danger.opacity(0.7) : Theme.Colors.finchSky.opacity(0.7))
                    .frame(width: 14, height: 4)
                    .rotationEffect(.degrees(-35))
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .padding(.vertical, 4)
    }

    private var postcardCanvas: some View {
        VStack(spacing: 14) {
            // Postmark & Header Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(postcard.locationTag.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .tracking(1.2)
                    Text(postcard.destination)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Sent during: \(postcard.dateEarned)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Spacer()

                // Vintage cancellation stamp
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            accentColor.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 2])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(accentColor.opacity(0.08))
                        )
                        .frame(width: 52, height: 60)

                    VStack(spacing: 2) {
                        Image("pip_happy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                        Text("AIRMAIL")
                            .font(.system(size: 7, weight: .black, design: .rounded))
                            .foregroundStyle(accentColor)
                    }
                }
            }

            // Postcard Scenery Illustration
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.22),
                                accentColor.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)

                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)

                        Image(systemName: postcard.icon)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(accentColor)
                    }

                    Text(postcard.destination)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }

            // Pip's Letter
            VStack(alignment: .leading, spacing: 8) {
                Text("“\(friendStore.personalized(postcard.story))”")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(5)

                HStack {
                    Spacer()
                    Text("— With love, \(friendStore.name)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.finchMint)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Colors.parchmentBorder, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        )
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(accentColor)
                Text("\(friendStore.name)'s Trail Question")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Text(postcard.prompt)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(spacing: 8) {
                ForEach(postcard.choices, id: \.self) { choice in
                    let isSelected = selectedChoice == choice
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedChoice = choice
                        }
                        Haptics.tap()
                    } label: {
                        HStack {
                            Text(choice)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? Color.white : Theme.Colors.textPrimary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? accentColor : Theme.Colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? accentColor : Theme.Colors.parchmentBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selectedChoice = selectedChoice {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16))
                    Text("\(friendStore.name) agrees! '\(selectedChoice) is a wonderful choice for keeping our energy lifted!'")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.finchMint)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.finchMint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Colors.parchmentBorder.opacity(0.8), lineWidth: 1)
                )
        )
    }

    private var claimRewardsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image("icon_seed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text("+30 Seeds Earned")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.finchMint)
                }

                Text("·")
                    .foregroundStyle(Theme.Colors.textTertiary)

                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 11))
                    Text("Saved to Scrapbook")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.surfaceRaised, in: Capsule())

            Button {
                let choice = selectedChoice ?? postcard.choices.first ?? "Care"
                friendStore.claimAdventureReward(choice: choice)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                    Text("Save Postcard & Claim +30 Seeds")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.Colors.finchMint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Theme.Colors.finchMint.opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Postcard Scrapbook Sheet
struct PostcardScrapbookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var friendStore: FuelFriendStore
    @State private var inspectingPostcard: FuelFriendStore.Postcard? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        headerSection

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(FuelFriendStore.allDestinations) { card in
                                let isCollected = friendStore.collectedPostcards.contains(card.id)
                                postcardThumbnail(card: card, isCollected: isCollected)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Travel Scrapbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.finchMint)
                }
            }
            .sheet(item: $inspectingPostcard) { card in
                PostcardDetailInspectorSheet(card: card, companionName: friendStore.name)
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.finchPeach.opacity(0.16))
                    .frame(width: 48, height: 48)
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Colors.finchPeach)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(friendStore.name)'s Expeditions")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(friendStore.collectedPostcards.count) of \(FuelFriendStore.allDestinations.count) postcards discovered")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image("icon_seed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text("\(friendStore.seeds)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.finchMint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.Colors.surfaceRaised, in: Capsule())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Colors.parchmentBorder, lineWidth: 1)
                )
        )
    }

    private func postcardThumbnail(card: FuelFriendStore.Postcard, isCollected: Bool) -> some View {
        let accent = Color(hex: card.accentColorHex)

        return Button {
            if isCollected {
                inspectingPostcard = card
                Haptics.tap()
            } else {
                Haptics.warning()
            }
        } label: {
            VStack(spacing: 10) {
                if isCollected {
                    // Collected Card Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.2),
                                        accent.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 85)

                        VStack(spacing: 4) {
                            Image(systemName: card.icon)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(accent)
                            Text(card.locationTag)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                        }

                        // Airmail Stamp
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(accent)
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.destination)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(card.dateEarned)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 3) {
                        Text("Read")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    // Mystery Locked Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.Colors.surfaceRaised)
                            .frame(height: 85)

                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Theme.Colors.textTertiary.opacity(0.7))
                            Text("Mystery Trail")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.destination)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .lineLimit(1)
                        Text(card.locationTag)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary.opacity(0.7))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 3) {
                        Image(systemName: "compass.drawing")
                            .font(.system(size: 10))
                        Text("Explore soon")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isCollected ? accent.opacity(0.4) : Theme.Colors.parchmentBorder.opacity(0.7),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Postcard Detail Inspector Sheet
struct PostcardDetailInspectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: FuelFriendStore.Postcard
    let companionName: String

    private var accentColor: Color {
        Color(hex: card.accentColorHex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 14) {
                            // Header
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(card.locationTag.uppercased())
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(accentColor)
                                        .tracking(1.2)
                                    Text(card.destination)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text("Collected on: \(card.dateEarned)")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }

                                Spacer()

                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            accentColor.opacity(0.6),
                                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 2])
                                        )
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(accentColor.opacity(0.08))
                                        )
                                        .frame(width: 52, height: 60)

                                    VStack(spacing: 2) {
                                        Image("pip_happy")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 32, height: 32)
                                        Text("AIRMAIL")
                                            .font(.system(size: 7, weight: .black, design: .rounded))
                                            .foregroundStyle(accentColor)
                                    }
                                }
                            }

                            // Scene
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                accentColor.opacity(0.22),
                                                accentColor.opacity(0.06)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(height: 140)

                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.85))
                                            .frame(width: 64, height: 64)
                                            .shadow(color: Color.black.opacity(0.06), radius: 6, y: 3)

                                        Image(systemName: card.icon)
                                            .font(.system(size: 30, weight: .bold))
                                            .foregroundStyle(accentColor)
                                    }

                                    Text(card.destination)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                }
                            }

                            // Story
                            VStack(alignment: .leading, spacing: 8) {
                                Text("“\(card.story.replacingOccurrences(of: "Pip", with: companionName))”")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineSpacing(5)

                                HStack {
                                    Spacer()
                                    Text("— Love, \(companionName)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.finchMint)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Theme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Theme.Colors.parchmentBorder, lineWidth: 1.5)
                                )
                                .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
                        )

                        // Trail prompt
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trail Reflection")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text(card.prompt)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            HStack(spacing: 8) {
                                ForEach(card.choices, id: \.self) { c in
                                    Text(c)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Theme.Colors.surface, in: Capsule())
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.finchMint)
                }
            }
        }
    }
}

