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
    @State private var showRenameAlert = false
    @State private var tempName = ""

    @State private var lastMealCount: Int? = nil
    @State private var lastWaterCount: Int? = nil
    @State private var isInitialSetup = true

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
        .sheet(isPresented: $showPalsSheet) {
            FoodPalsSheet(friendStore: friendStore)
        }
        .onAppear {
            startCompanionAnimations()
            lastMealCount = mealCount
            lastWaterCount = water
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isInitialSetup = false
            }

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
            if args.contains("-showPals") || UserDefaults.standard.bool(forKey: "showPals") {
                showPalsSheet = true
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
        .onChange(of: mealCount) { count in
            guard !isInitialSetup else {
                lastMealCount = count
                return
            }
            if let last = lastMealCount, count > last {
                friendStore.feed(mealName: "Nourishing Meal")
            }
            lastMealCount = count
        }
        .onChange(of: water) { count in
            guard !isInitialSetup else {
                lastWaterCount = count
                return
            }
            if let last = lastWaterCount, count > last {
                friendStore.hydrate()
            }
            lastWaterCount = count
        }
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
            if usePuppetFallback {
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
                Image(systemName: mood.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(mood.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.Colors.finchMint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.Colors.finchMint.opacity(0.12), in: Capsule())

            Spacer()

            Button {
                showPalsSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text("🥑 Pals")
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
        .padding(.horizontal, 4)
    }

    // MARK: - Quick Interaction Chips Row
    private var actionChipsRow: some View {
        HStack(spacing: 10) {
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

            // Toggle Video / Puppet Mode
            Button {
                withAnimation(.spring(response: 0.35)) {
                    usePuppetFallback.toggle()
                }
                Haptics.tap()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: usePuppetFallback ? "film.fill" : "hand.draw.fill")
                        .font(.system(size: 11))
                    Text(usePuppetFallback ? "Loop" : "Puppet")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.Colors.surfaceRaised, in: Capsule())
            }
            .buttonStyle(.plain)
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
                title: "Shield",
                icon: "checkmark.shield.fill",
                progress: 1.0,
                color: Theme.Colors.safe
            )
        }
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
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isActive ? Color.white : color)
            .padding(.horizontal, 10)
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

        Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                footTap.toggle()
            }
        }

        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                headTilt = Double.random(in: -3.5...3.5)
            }
        }

        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
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
                            .font(.system(size: 22, weight: .bold, design: .serif))
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
                Text(pal.icon)
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
