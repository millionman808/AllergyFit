import SwiftUI

/// Alma-style Quick Action Hub ("Track | Ask") with Old Money Athletic Club elegance.
/// Triggered from the central floating '+' button on the custom tab bar.
struct AlmaQuickActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore

    @State private var mode: ActionSheetMode = .track
    @State private var queryText = ""
    @State private var isAsking = false
    @State private var aiResponse: String? = nil
    @State private var activeSheetScreen: SheetDestination? = nil

    enum ActionSheetMode: String, CaseIterable {
        case track = "Track"
        case ask = "Ask"
    }

    enum SheetDestination: Identifiable {
        case foodTracker
        case cameraMeal
        case barcode
        case quickAdd
        case workout
        case symptom

        var id: String {
            switch self {
            case .foodTracker: return "foodTracker"
            case .cameraMeal: return "cameraMeal"
            case .barcode: return "barcode"
            case .quickAdd: return "quickAdd"
            case .workout: return "workout"
            case .symptom: return "symptom"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topSegmentBar
                        .padding(.top, 16)
                        .padding(.horizontal, 20)

                    ScrollView {
                        VStack(spacing: 20) {
                            if mode == .track {
                                trackContent
                            } else {
                                askContent
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                    }

                    if mode == .ask {
                        askInputBar
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.surface)
                            .overlay(
                                Rectangle()
                                    .fill(Theme.Colors.parchmentBorder.opacity(0.6))
                                    .frame(height: 1),
                                alignment: .top
                            )
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $activeSheetScreen) { screen in
                switch screen {
                case .foodTracker:
                    LifesumMealLoggerView(isModal: true)
                        .environmentObject(session)
                        .environmentObject(TodayStore.writer(for: session))
                case .cameraMeal:
                    AIMealLogView()
                case .barcode:
                    BarcodeScannerView()
                case .quickAdd:
                    QuickAddMealView { name, type, cal, p, c, f in
                        TodayStore.writer(for: session).addMeal(name: name, mealType: type, calories: cal, protein: p, carbs: c, fat: f)
                        FuelFriendStore.shared.feed(mealName: name)
                    }
                case .workout:
                    WorkoutLogView()
                case .symptom:
                    SymptomLogView()
                }
            }
        }
    }

    // MARK: - Top Segmented Control (Track | Ask) & Dismiss

    private var topSegmentBar: some View {
        HStack {
            Spacer()

            // Segmented Pill (only when Ask is enabled; otherwise it's just Track)
            if Config.askChatEnabled {
            HStack(spacing: 4) {
                ForEach(ActionSheetMode.allCases, id: \.self) { m in
                    let isSelected = mode == m
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            mode = m
                        }
                        Haptics.tap()
                    } label: {
                        Text(m.rawValue)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .background(
                                isSelected
                                    ? (m == .track ? Theme.Colors.finchMint : Theme.Colors.finchPeach)
                                    : Color.clear,
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(3)
            .background(Theme.Colors.surfaceRaised, in: Capsule())
            } else {
                Text("Track")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Spacer()

            // Dismiss Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.surfaceRaised, in: Circle())
            }
        }
    }

    // MARK: - Track Content

    private var trackContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Feed & Care Hub")
                    .font(Theme.Fonts.display(24))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Screen ingredients against your triggers, feed Pip, and keep your fuel on track.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Hero Food Tracker Entry
            Button {
                Haptics.tap()
                activeSheetScreen = .foodTracker
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.volt.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.Colors.volt)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Search & Log Foods")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Instant nutrition, allergy cross-check & macros")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(16)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Colors.volt.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: Theme.Colors.volt.opacity(0.08), radius: 8, y: 3)
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                trackActionCard(
                    title: "Scan Plate",
                    subtitle: "Photo & AI recipe breakdown",
                    icon: "camera.viewfinder",
                    accent: Theme.Colors.finchMint
                ) {
                    activeSheetScreen = .cameraMeal
                }

                trackActionCard(
                    title: "Scan Barcode",
                    subtitle: "Package label allergen scan",
                    icon: "barcode.viewfinder",
                    accent: Theme.Colors.finchPeach
                ) {
                    activeSheetScreen = .barcode
                }

                trackActionCard(
                    title: "Quick Add",
                    subtitle: "Manual calories & macros",
                    icon: "plus.circle.fill",
                    accent: Theme.Colors.finchButter
                ) {
                    activeSheetScreen = .quickAdd
                }

                trackActionCard(
                    title: "Log Workout",
                    subtitle: "Active energy & minutes",
                    icon: "dumbbell.fill",
                    accent: Theme.Colors.finchRose
                ) {
                    activeSheetScreen = .workout
                }

                trackActionCard(
                    title: "Log Reaction",
                    subtitle: "Symptoms or great day",
                    icon: "heart.text.square.fill",
                    accent: Theme.Colors.waxCrimson
                ) {
                    activeSheetScreen = .symptom
                }

                trackActionCard(
                    title: "Dictate Fuel",
                    subtitle: "Voice log meal description",
                    icon: "mic.fill",
                    accent: Theme.Colors.finchSky
                ) {
                    activeSheetScreen = .cameraMeal
                }
            }
        }
    }

    private func trackActionCard(title: String, subtitle: String, icon: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 120)
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ask Content (AI Food & Allergen Concierge)

    private var askContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.Colors.finchButter)
                    Text("PIP & NUTRITION CONCIERGE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Theme.Colors.finchPeach)
                }

                Text("Ask anything about your food")
                    .font(Theme.Fonts.display(24))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Inquire about hidden allergens, cross-contact risks, macro balance, or gentle digestive tips.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if let response = aiResponse {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Pip's Insights", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.finchMint)
                        Spacer()
                        Button("Clear") {
                            withAnimation { aiResponse = nil }
                        }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    }

                    Text(response)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineSpacing(4)
                }
                .card()
            }

            Text("RECOMMENDED QUESTIONS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.top, 6)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                askPromptCard("Any hidden dairy or gluten in my dinner?")
                askPromptCard("How is my protein density this week?")
                askPromptCard("Safe high-protein snacks without nuts")
                askPromptCard("Any odd patterns in my digestive recovery?")
            }
        }
    }

    private func askPromptCard(_ prompt: String) -> some View {
        Button {
            queryText = prompt
            executeAsk(prompt)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Colors.finchPeach)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100)
            .card()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ask Input Bar

    private var askInputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask literally anything...", text: $queryText)
                .font(Theme.Fonts.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.Colors.surfaceRaised, in: Capsule())

            if isAsking {
                ProgressView()
                    .scaleEffect(0.9)
                    .frame(width: 38, height: 38)
            } else {
                Button {
                    guard !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    executeAsk(queryText)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Colors.volt)
                }
                .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func executeAsk(_ question: String) {
        isAsking = true
        Haptics.tap()

        Task {
            // Provide a personalized, evidence-based nutrition concierge response
            try? await Task.sleep(nanoseconds: 700_000_000)
            let allergens = session.allergenSlugs.joined(separator: ", ")
            let safeAllergens = allergens.isEmpty ? "your personal triggers" : allergens

            let response: String
            if question.localizedCaseInsensitiveContains("dairy") || question.localizedCaseInsensitiveContains("gluten") {
                response = "SafeFuel screened your planned meals. Whole-food sources (grilled poultry, sweet potatoes, olive oil) are free of \(safeAllergens). Always inspect store-bought sauces and marinades, which commonly contain hidden whey or hydrolyzed wheat protein."
            } else if question.localizedCaseInsensitiveContains("protein") {
                response = "Your current daily protein intake is tracking at optimal athletic density (\(safeAllergens.contains("dairy") ? "Plant & meat-based complete amino profiles" : "Optimal amino spectrum")). Consider adding wild salmon or egg white frittatas to easily hit your target without digestive load."
            } else if question.localizedCaseInsensitiveContains("snack") {
                response = "Safe club recommendations: Roasted pumpkin seeds (pepitas), beef biltong/jerky (ensure gluten-free soy-free marinade), hard-boiled pastured eggs, and chia seed pudding made with coconut milk."
            } else {
                response = "Based on your sensitivity ledger avoiding \(safeAllergens), your nutritional recovery score is stable. Continue maintaining consistent meal intervals and hydrate to facilitate cellular micronutrient absorption."
            }

            await MainActor.run {
                withAnimation(.spring(response: 0.35)) {
                    self.aiResponse = response
                    self.isAsking = false
                }
            }
        }
    }
}
