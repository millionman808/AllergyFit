import SwiftUI
import Supabase
import UIKit
import RevenueCat

// MARK: - Edit triggers

struct EditTriggersView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>          // slugs
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let allSlugs = ["peanut", "tree_nut", "dairy", "egg", "wheat", "gluten",
                            "soy", "fish", "shellfish", "sesame", "corn", "nightshade",
                            "histamine", "fodmap", "sulfite", "mustard", "celery", "alpha_gal"]

    init(currentSlugs: [String]) {
        _selected = State(initialValue: Set(currentSlugs))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tap the foods you react to. Every meal, recipe, and swap is filtered against this list.")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                            ForEach(allSlugs, id: \.self) { slug in
                                let on = selected.contains(slug)
                                Button {
                                    if on { selected.remove(slug) } else { selected.insert(slug) }
                                } label: {
                                    Text(AllergenCatalog.nameBySlug[slug] ?? slug)
                                        .font(Theme.Fonts.caption)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity).frame(height: 40)
                                        .background(on ? Theme.Colors.volt : Theme.Colors.surface)
                                        .foregroundStyle(on ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        if let errorMessage {
                            Text(errorMessage).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
                        }
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Your triggers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await save() } } label: {
                        if isSaving { ProgressView() } else { Text("Save").bold() }
                    }
                    .foregroundStyle(Theme.Colors.volt)
                    .disabled(isSaving)
                }
            }
        }
        .preferredColorScheme(nil)
    }

    private func save() async {
        session.allergenSlugs = selected.isEmpty ? [] : Array(selected)
        guard !session.isDemo, let userId = session.session?.user.id else { dismiss(); return }
        isSaving = true
        defer { isSaving = false }
        do {
            struct ARow: Codable { let id: Int; let slug: String }
            let known: [ARow] = try await Backend.client.from("allergens").select("id, slug").execute().value
            let idBySlug = Dictionary(uniqueKeysWithValues: known.map { ($0.slug, $0.id) })
            // replace the set: delete existing, insert selected
            try await Backend.client.from("user_allergens").delete().eq("user_id", value: userId).execute()
            struct Ins: Codable { let user_id: UUID; let allergen_id: Int; let severity: String }
            let rows = selected.compactMap { idBySlug[$0] }.map { Ins(user_id: userId, allergen_id: $0, severity: "moderate") }
            if !rows.isEmpty { try await Backend.client.from("user_allergens").insert(rows).execute() }
            await session.reloadAllergens(userId: userId)
            dismiss()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Goals & targets editor

struct GoalsEditorView: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    private let goals: [(String, String, String)] = [
        ("cut", "Cut", "flame.fill"), ("build", "Build muscle", "dumbbell.fill"), ("maintain", "Maintain", "scalemass.fill"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Metrics.spacing) {
                        VStack(spacing: 8) {
                            ForEach(goals, id: \.0) { g in
                                Button { store.goal = g.0; recompute() } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: g.2).foregroundStyle(store.goal == g.0 ? Theme.Colors.onVolt : Theme.Colors.volt)
                                            .frame(width: 40, height: 40)
                                            .background(store.goal == g.0 ? Theme.Colors.volt : Theme.Colors.surfaceRaised, in: Circle())
                                        Text(g.1).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                                        Spacer()
                                        Image(systemName: store.goal == g.0 ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(store.goal == g.0 ? Theme.Colors.volt : Theme.Colors.textTertiary)
                                    }
                                    .card()
                                }
                            }
                        }
                        stepper("Weight", "\(store.weightLb) lb") { store.weightKg = max(36, store.weightKg - 2.27); recompute() } up: { store.weightKg += 2.27; recompute() }
                        stepper("Height", "\(store.heightFeet)′ \(store.heightInches)″") { store.heightCm = max(122, store.heightCm - 2.54); recompute() } up: { store.heightCm += 2.54; recompute() }
                        stepper("Age", "\(store.age)") { store.age = max(13, store.age - 1); recompute() } up: { store.age = min(90, store.age + 1); recompute() }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Training days per week").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { d in
                                    Button { store.trainingDays = d; recompute() } label: {
                                        Text("\(d)").font(Theme.Fonts.stat(16)).frame(maxWidth: .infinity).frame(height: 38)
                                            .background(store.trainingDays == d ? Theme.Colors.volt : Theme.Colors.surfaceRaised)
                                            .foregroundStyle(store.trainingDays == d ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                        }.card()

                        // Live targets preview
                        VStack(spacing: 8) {
                            Text("Your daily targets").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                            Text("\(store.targetCalories.formatted())").font(Theme.Fonts.stat(44)).foregroundStyle(Theme.Colors.volt)
                            Text("calories").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                            HStack(spacing: 14) {
                                pill("\(store.targetProtein)g", "protein", Theme.Colors.protein)
                                pill("\(store.targetCarbs)g", "carbs", Theme.Colors.carbs)
                                pill("\(store.targetFat)g", "fat", Theme.Colors.fat)
                            }
                        }.frame(maxWidth: .infinity).card()
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Goals & targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.Colors.textSecondary) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { isSaving = true; await store.saveGoals(); isSaving = false; dismiss() } } label: {
                        if isSaving { ProgressView() } else { Text("Save").bold() }
                    }.foregroundStyle(Theme.Colors.volt).disabled(isSaving)
                }
            }
        }
    }

    private func recompute() {
        let t = TargetsCalc.compute(weightKg: store.weightKg, heightCm: store.heightCm, age: store.age,
                                    trainingDays: store.trainingDays, goal: store.goal)
        withAnimation(.spring(response: 0.3)) {
            store.targetCalories = t.calories; store.targetProtein = t.protein
            store.targetCarbs = t.carbs; store.targetFat = t.fat
        }
    }

    private func stepper(_ label: String, _ value: String, down: @escaping () -> Void, up: @escaping () -> Void) -> some View {
        HStack {
            Text(label).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button(action: down) { Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(Theme.Colors.surfaceRaised, Theme.Colors.textSecondary) }
            Text(value).font(Theme.Fonts.stat(20)).foregroundStyle(Theme.Colors.textPrimary).frame(minWidth: 96)
            Button(action: up) { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.Colors.volt.opacity(0.25), Theme.Colors.volt) }
        }.card()
    }

    private func pill(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) { Text(v).font(Theme.Fonts.stat(18)).foregroundStyle(c); Text(l).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Theme.Colors.textSecondary) }
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Dietary preferences

struct DietaryPrefsView: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var isSaving = false
    private let options = ["Vegan", "Vegetarian", "Pescatarian", "Halal", "Kosher",
                           "Keto", "Paleo", "Low FODMAP", "Low sodium", "High protein"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The meal planner and recipe search respect these on top of your allergen triggers.")
                            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            ForEach(options, id: \.self) { opt in
                                let on = selected.contains(opt)
                                Button { if on { selected.remove(opt) } else { selected.insert(opt) } } label: {
                                    Text(opt).font(Theme.Fonts.caption).lineLimit(1).minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity).frame(height: 40)
                                        .background(on ? Theme.Colors.volt : Theme.Colors.surface)
                                        .foregroundStyle(on ? Theme.Colors.onVolt : Theme.Colors.textSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }.padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Dietary preferences")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { selected = Set(store.dietaryPreferences) }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.Colors.textSecondary) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.dietaryPreferences = Array(selected)
                        Task { isSaving = true; await store.saveDietary(); isSaving = false; dismiss() }
                    } label: { if isSaving { ProgressView() } else { Text("Save").bold() } }
                        .foregroundStyle(Theme.Colors.volt).disabled(isSaving)
                }
            }
        }
    }
}

// MARK: - Notifications

struct NotificationsView: View {
    @StateObject private var reminders = ReminderManager()

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Metrics.spacing) {
                    toggleCard("Meal reminders", "Breakfast, lunch, and dinner nudges to keep logging.",
                               "fork.knife", isOn: reminders.mealRemindersOn) { on in
                        Task { await reminders.setMealReminders(on) }
                    }
                    toggleCard("Symptom check-in", "An evening reminder to log how you feel.",
                               "heart.text.square.fill", isOn: reminders.symptomReminderOn) { on in
                        Task { await reminders.setSymptomReminder(on) }
                    }
                    if !reminders.authorized {
                        Text("If reminders don't appear, enable notifications for AllergyFit in the Settings app.")
                            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reminders.refreshStatus() }
    }

    private func toggleCard(_ title: String, _ subtitle: String, _ icon: String, isOn: Bool, action: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.Colors.volt).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: { action($0) })).labelsHidden().tint(Theme.Colors.volt)
        }.card()
    }
}

// MARK: - Manage subscription

struct SubscriptionView: View {
    @EnvironmentObject var purchases: PurchasesManager
    @Environment(\.openURL) private var openURL
    @State private var busy = false

    private let perks = [
        ("infinity", "Unlimited AI meal plans & recipes"),
        ("arrow.triangle.2.circlepath", "One-Tap ingredient swaps"),
        ("cart.fill", "Auto grocery lists"),
        ("barcode.viewfinder", "Barcode safe/unsafe scanning"),
        ("waveform.path.ecg", "Reaction-learning insights"),
        ("person.2.fill", "Family profiles"),
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.Metrics.spacing) {
                    header
                    perksCard

                    if purchases.hasPremiumAccess && !purchases.isConfigured {
                        betaBanner
                    }

                    if purchases.isConfigured {
                        if purchases.isPremium {
                            activeBanner
                        } else if purchases.isLoadingOfferings {
                            ProgressView().tint(Theme.Colors.volt).padding(.vertical, 30)
                        } else if purchases.packages.isEmpty {
                            Text("No plans available yet — finish setting up products in App Store Connect and RevenueCat.")
                                .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center).padding(.vertical, 20)
                        } else {
                            ForEach(purchases.packages, id: \.identifier) { pkg in
                                packageButton(pkg)
                            }
                        }
                    } else {
                        // Preview pricing until billing is wired up
                        previewCard("Annual", "$39.99 / year", "Best value · 3-day free trial", featured: true)
                        previewCard("Monthly", "$7.99 / month", "Cancel anytime", featured: false)
                        previewCard("Lifetime", "$99 once", "Founder deal · limited time", featured: false)
                    }

                    if let err = purchases.purchaseError {
                        Text(err).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger).multilineTextAlignment(.center)
                    }

                    HStack(spacing: 16) {
                        Button("Restore purchases") {
                            busy = true
                            Task { await purchases.restore(); busy = false }
                        }
                        .disabled(!purchases.isConfigured || busy)
                        Button("Manage in App Store") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                        }
                    }
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary).padding(.top, 4)

                    Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the period ends.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.Colors.textTertiary).multilineTextAlignment(.center)
                }
                .padding(Theme.Metrics.screenPadding)
            }
            if busy {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView().tint(Theme.Colors.volt)
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .task { await purchases.loadOfferings() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill").font(.system(size: 40)).foregroundStyle(Theme.Colors.volt)
            Text("AllergyFit Premium").font(Theme.Fonts.title).foregroundStyle(Theme.Colors.textPrimary)
            Text("The coach that keeps you safe and on-target — unlocked.")
                .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 8).card()
    }

    private var perksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(perks, id: \.1) { perk in
                HStack(spacing: 12) {
                    Image(systemName: perk.0).foregroundStyle(Theme.Colors.volt).frame(width: 26)
                    Text(perk.1).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "checkmark").font(.caption).foregroundStyle(Theme.Colors.safe)
                }
            }
        }.card()
    }

    private var betaBanner: some View {
        Label("You have full access during the beta.", systemImage: "sparkles")
            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.volt)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Theme.Colors.volt.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var activeBanner: some View {
        Label("Premium active — thank you!", systemImage: "checkmark.seal.fill")
            .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.safe)
            .frame(maxWidth: .infinity).padding(.vertical, 14).card()
    }

    private func packageButton(_ pkg: Package) -> some View {
        let annual = pkg.packageType == .annual
        let lifetime = pkg.packageType == .lifetime
        // Prefer the real free-trial length from the App Store product; fall back to
        // "Best value" on annual / "Founder deal" on lifetime.
        let subtitle = trialText(pkg)
            ?? (annual ? "Best value" : (lifetime ? "Founder deal — limited time" : nil))
        return Button {
            busy = true
            Task { await purchases.purchase(pkg); busy = false }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pkg.storeProduct.localizedTitle.isEmpty
                         ? (annual ? "Annual" : lifetime ? "Lifetime" : "Monthly")
                         : pkg.storeProduct.localizedTitle)
                        .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                    if let subtitle { Text(subtitle).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.volt) }
                }
                Spacer()
                Text(pkg.storeProduct.localizedPriceString).font(Theme.Fonts.stat(17)).foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(Theme.Metrics.cardPadding)
            .background(Theme.Colors.surface)
            .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .stroke(annual ? Theme.Colors.volt : .clear, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        }
        .disabled(busy)
    }

    /// Reads the free-trial length from the product's intro offer (e.g. "3-week free trial"),
    /// so the paywall always matches whatever is configured in App Store Connect.
    private func trialText(_ pkg: Package) -> String? {
        guard let intro = pkg.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
        let n = period.value
        let unit: String
        switch period.unit {
        case .day:   unit = n == 1 ? "day" : "days"
        case .week:  unit = n == 1 ? "week" : "weeks"
        case .month: unit = n == 1 ? "month" : "months"
        case .year:  unit = n == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        return "\(n)-\(unit) free trial"
    }

    private func previewCard(_ name: String, _ price: String, _ note: String, featured: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                Text(note).font(Theme.Fonts.caption).foregroundStyle(featured ? Theme.Colors.volt : Theme.Colors.textSecondary)
            }
            Spacer()
            Text(price).font(Theme.Fonts.stat(17)).foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(Theme.Metrics.cardPadding)
        .background(Theme.Colors.surface)
        .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
            .stroke(featured ? Theme.Colors.volt : .clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
    }
}

// MARK: - Allergist PDF export

enum AllergistReport {
    static func makePDF(name: String, allergens: [String], goal: String,
                        calories: Int, protein: Int) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AllergyFit-Report.pdf")
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let title = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 24, weight: .bold)]
                let h2 = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15, weight: .semibold)]
                let body = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]
                let muted = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10),
                             .foregroundColor: UIColor.gray]
                var y: CGFloat = 48
                "AllergyFit — Allergen & Nutrition Summary".draw(at: CGPoint(x: 48, y: y), withAttributes: title); y += 40
                "Prepared for: \(name)".draw(at: CGPoint(x: 48, y: y), withAttributes: body); y += 18
                "Date: \(Date().formatted(date: .abbreviated, time: .omitted))".draw(at: CGPoint(x: 48, y: y), withAttributes: body); y += 34

                "Diagnosed / self-reported allergens".draw(at: CGPoint(x: 48, y: y), withAttributes: h2); y += 22
                if allergens.isEmpty {
                    "None recorded".draw(at: CGPoint(x: 60, y: y), withAttributes: body); y += 18
                } else {
                    for a in allergens { "•  \(a)".draw(at: CGPoint(x: 60, y: y), withAttributes: body); y += 18 }
                }
                y += 20
                "Nutrition goals".draw(at: CGPoint(x: 48, y: y), withAttributes: h2); y += 22
                "Goal: \(goal)".draw(at: CGPoint(x: 60, y: y), withAttributes: body); y += 18
                "Daily target: \(calories) kcal · \(protein) g protein".draw(at: CGPoint(x: 60, y: y), withAttributes: body); y += 40

                let disclaimer = "This report is generated by AllergyFit, a lifestyle tool and not a medical device. Allergen entries are self-reported or scanned by the user and must be confirmed by a licensed allergist. Always verify physical food labels and carry prescribed epinephrine."
                disclaimer.draw(in: CGRect(x: 48, y: 720, width: 516, height: 48), withAttributes: muted)
            }
            return url
        } catch {
            print("pdf failed: \(error)")
            return nil
        }
    }
}
