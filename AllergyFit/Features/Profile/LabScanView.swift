import SwiftUI
import PhotosUI
import Supabase

// MARK: - Models

struct LabResult: Codable {
    var isAllergyTest: Bool
    var tests: [LabTest]
    var summary: String
    var error: String?

    enum CodingKeys: String, CodingKey {
        case isAllergyTest = "is_allergy_test"
        case tests, summary, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isAllergyTest = try c.decodeIfPresent(Bool.self, forKey: .isAllergyTest) ?? false
        tests = try c.decodeIfPresent([LabTest].self, forKey: .tests) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

struct LabTest: Codable, Identifiable {
    var id: String { allergen }
    var allergen: String
    var value: String
    var unit: String
    var level: String
    var positive: Bool
    var matchedSlug: String

    enum CodingKeys: String, CodingKey {
        case allergen, value, unit, level, positive
        case matchedSlug = "matched_slug"
    }
}

// MARK: - View

/// Scan a blood allergy test (IgE panel): photo → AI extraction → review → save triggers.
struct LabScanView: View {
    @EnvironmentObject var session: SessionStore

    enum Phase { case pick, analyzing, review, saved }

    @State private var phase: Phase = .pick
    @State private var photoItem: PhotosPickerItem?
    @State private var result: LabResult?
    @State private var enabled: Set<String> = []
    @State private var severityByAllergen: [String: Sensitivity] = [:]
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                    switch phase {
                    case .pick: pickSection
                    case .analyzing: analyzingSection
                    case .review, .saved: if let result { reviewSection(result) }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.danger)
                    }
                }
                .padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Scan blood test")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task { await analyze(item) }
        }
    }

    // MARK: Pick

    private var pickSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Colors.volt)
                .padding(.top, 30)
            Text("Add your allergy test results")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Take a photo of a blood IgE panel or skin test report. The AI reads the results, and you confirm before anything is saved to your triggers.")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose photo", systemImage: "photo.on.rectangle")
                    .font(Theme.Fonts.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.Colors.volt)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text("This is a convenience feature, not a diagnosis. Always confirm your allergen list with your allergist.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Analyzing

    private var analyzingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.Colors.volt)
            Text("Reading your results…")
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 90)
    }

    // MARK: Review

    @ViewBuilder
    private func reviewSection(_ result: LabResult) -> some View {
        if !result.isAllergyTest {
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.caution)
                Text("That doesn't look like an allergy test")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(result.summary)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Try another photo") { phase = .pick; photoItem = nil }
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.volt)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            Text("Found \(result.tests.count) result\(result.tests.count == 1 ? "" : "s")")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Toggle which ones to add to your triggers, then confirm.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            ForEach(result.tests) { test in
                let isOn = enabled.contains(test.allergen)
                let sev = severityByAllergen[test.allergen] ?? .moderate
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: test.positive ? "exclamationmark.shield.fill" : "checkmark.shield")
                            .foregroundStyle(test.positive ? Theme.Colors.danger : Theme.Colors.safe)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(test.allergen)
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("\(test.value) \(test.unit) · \(test.level)")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { enabled.contains(test.allergen) },
                            set: { on in
                                if on { enabled.insert(test.allergen) } else { enabled.remove(test.allergen) }
                            }
                        ))
                        .labelsHidden()
                        .tint(Theme.Colors.volt)
                    }
                    if isOn {
                        HStack {
                            Text("Sensitivity")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                            Spacer()
                            Menu {
                                ForEach(Sensitivity.allCases) { s in
                                    Button(s.label) { severityByAllergen[test.allergen] = s }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: sev.icon).font(.caption2)
                                    Text(sev.label).font(Theme.Fonts.caption)
                                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                                }
                                .foregroundStyle(sev.color)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(sev.color.opacity(0.14), in: Capsule())
                            }
                        }
                    }
                }
                .card()
            }

            Text(result.summary)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textTertiary)

            if phase == .saved {
                Label("Added to your triggers", systemImage: "checkmark.circle.fill")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.safe)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                Button {
                    Task { await saveTriggers(result) }
                } label: {
                    Text("Add \(enabled.count) to my triggers")
                        .font(Theme.Fonts.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(enabled.isEmpty ? Theme.Colors.surfaceRaised : Theme.Colors.volt)
                        .foregroundStyle(enabled.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.onVolt)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(enabled.isEmpty)
            }
        }
    }

    // MARK: Actions

    private func analyze(_ item: PhotosPickerItem) async {
        withAnimation { phase = .analyzing; errorMessage = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                throw NSError(domain: "LabScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't load that photo."])
            }
            let resized = resize(uiImage, maxDimension: 1568)
            guard let jpeg = resized.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "LabScan", code: 2, userInfo: [NSLocalizedDescriptionKey: "Couldn't process that photo."])
            }

            let url = Config.supabaseURL.appendingPathComponent("functions/v1/analyze-labs")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 120
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabasePublishableKey, forHTTPHeaderField: "apikey")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "image_base64": jpeg.base64EncodedString(),
                "media_type": "image/jpeg",
            ])
            let (data2, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(LabResult.self, from: data2)
            if let error = decoded.error {
                throw NSError(domain: "LabScan", code: 3, userInfo: [NSLocalizedDescriptionKey: error])
            }
            result = decoded
            enabled = Set(decoded.tests.filter(\.positive).map(\.allergen))
            severityByAllergen = Dictionary(
                decoded.tests.map { ($0.allergen, Sensitivity.fromLabLevel($0.level, positive: $0.positive)) },
                uniquingKeysWith: { a, _ in a }
            )
            withAnimation { phase = .review }
        } catch {
            withAnimation {
                errorMessage = error.localizedDescription
                phase = .pick
                photoItem = nil
            }
        }
    }

    private func saveTriggers(_ result: LabResult) async {
        if !session.isDemo, let userId = session.session?.user.id {
            struct AllergenRow: Codable { let id: Int, slug: String }
            struct InsertRow: Codable {
                let user_id: UUID
                let allergen_id: Int?
                let custom_name: String?
                let severity: String
            }
            do {
                let known: [AllergenRow] = try await Backend.client
                    .from("allergens").select("id, slug").execute().value
                let slugToId = Dictionary(uniqueKeysWithValues: known.map { ($0.slug, $0.id) })
                let rows = result.tests
                    .filter { enabled.contains($0.allergen) }
                    .map { test in
                        InsertRow(
                            user_id: userId,
                            allergen_id: slugToId[test.matchedSlug],
                            custom_name: slugToId[test.matchedSlug] == nil ? test.allergen : nil,
                            severity: (severityByAllergen[test.allergen] ?? .moderate).rawValue
                        )
                    }
                // Replace any existing rows for these known allergens, then insert
                // (the unique index on allergen_id is partial, so a plain upsert
                // can't reliably infer the conflict target — delete + insert is safe).
                let knownIds = rows.compactMap { $0.allergen_id }
                if !knownIds.isEmpty {
                    try await Backend.client.from("user_allergens")
                        .delete().eq("user_id", value: userId).in("allergen_id", values: knownIds)
                        .execute()
                }
                if !rows.isEmpty {
                    try await Backend.client.from("user_allergens").insert(rows).execute()
                }
                await session.reloadAllergens(userId: userId)
            } catch {
                errorMessage = "Save failed: \(error.localizedDescription)"
                return
            }
        }
        withAnimation { phase = .saved }
    }

    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
