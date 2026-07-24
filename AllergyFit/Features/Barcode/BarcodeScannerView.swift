import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @EnvironmentObject var session: SessionStore
    @State private var manualCode = ""
    @State private var isLooking = false
    @State private var product: ScannedProduct?
    @State private var notFound = false
    @State private var errorMessage: String?
    @State private var cameraAvailable = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if cameraAvailable {
                    ZStack {
                        CameraScanner { code in handleScan(code) }
                            .ignoresSafeArea(edges: .top)
                        // scan reticle
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.Colors.volt, lineWidth: 3)
                            .frame(width: 260, height: 150)
                        VStack {
                            Spacer()
                            Text("Point at a product barcode")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(.black.opacity(0.5), in: Capsule())
                                .padding(.bottom, 24)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    noCameraSection
                }

                VStack(spacing: 6) {
                    Text("Can't scan it? Type the barcode number")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    manualEntryBar
                }
                .padding(.top, 8)
                .padding(.bottom, Theme.Metrics.tabBarClearance)
            }
        }
        .navigationTitle("Scan a product")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cameraAvailable = AVCaptureDevice.default(for: .video) != nil
        }
        .sheet(item: $product) { p in
            ProductResultView(product: p, session: session)
        }
        .overlay {
            if isLooking {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Looking up…").tint(Theme.Colors.volt)
                        .padding(24).background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .alert("Product not found", isPresented: $notFound) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This item isn't in the Open Food Facts database yet. You can still log it manually from the Log screen.")
        }
        .alert("Lookup failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var noCameraSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.volt)
            Text("Scan a packaged food")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("On a real device, point your camera at any barcode for an instant safe/unsafe verdict. In the simulator, type a barcode below to try it.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Metrics.screenPadding)
    }

    private var manualEntryBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "number")
                .foregroundStyle(Theme.Colors.textTertiary)
            TextField("Enter barcode number", text: $manualCode)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .keyboardType(.numberPad)
            Button {
                handleScan(manualCode)
            } label: {
                Text("Check")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.onVolt)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(manualCode.count < 6 ? Theme.Colors.surfaceRaised : Theme.Colors.volt, in: Capsule())
            }
            .disabled(manualCode.count < 6)
        }
        .padding(14)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(Theme.Metrics.screenPadding)
    }

    private func handleScan(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        // Don't fire again while looking up, while a result/alert is already up,
        // or the camera's continuous stream would loop on the same barcode.
        guard trimmed.count >= 6, !isLooking, product == nil,
              !notFound, errorMessage == nil else { return }
        isLooking = true
        errorMessage = nil
        // @MainActor so the @State writes reliably drive the sheet/alert on device
        // (off-main SwiftUI state updates silently fail to present — the bug here).
        Task { @MainActor in
            defer { isLooking = false }
            do {
                if let p = try await BarcodeService.lookup(barcode: trimmed, userAllergens: session.allergenSlugs) {
                    UINotificationFeedbackGenerator().notificationOccurred(p.isSafe ? .success : .warning)
                    product = p
                } else {
                    notFound = true
                }
            } catch {
                errorMessage = "Couldn't look that up. Check your connection and try again."
            }
        }
    }
}

// MARK: - Result

extension ScannedProduct: Identifiable { var id: String { barcode } }

struct ProductResultView: View {
    @Environment(\.dismiss) private var dismiss
    let product: ScannedProduct
    @ObservedObject var session: SessionStore
    @State private var servings: Double = 1
    @State private var grams: Double = 100
    @State private var isLogging = false
    @State private var logged = false

    private var hasMacros: Bool { product.caloriesPer100g != nil || product.proteinPer100g != nil }
    /// Grams in one serving, parsed from the label text if present (e.g. "30 g").
    private var servingGrams: Double? {
        guard let s = product.servingSizeText,
              let re = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*g"#),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return Double(s[r])
    }
    private var effectiveGrams: Double { (servingGrams.map { $0 * servings }) ?? grams }
    private func scaled(_ per100: Double?) -> Int { Int((((per100 ?? 0) * effectiveGrams) / 100).rounded()) }
    private var scaledCalories: Int { Int(((Double(product.caloriesPer100g ?? 0) * effectiveGrams) / 100).rounded()) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Metrics.spacing) {
                        // Verdict banner
                        HStack(spacing: 12) {
                            Image(systemName: product.isSafe ? "checkmark.shield.fill" : "xmark.shield.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(product.isSafe ? Theme.Colors.safe : Theme.Colors.danger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.isSafe ? "Safe for you" : "Contains your triggers")
                                    .font(Theme.Fonts.title)
                                    .foregroundStyle(product.isSafe ? Theme.Colors.safe : Theme.Colors.danger)
                                if !product.isSafe {
                                    Text(AllergenCatalog.names(for: product.flaggedSlugs).joined(separator: ", "))
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(Theme.Colors.danger)
                                }
                            }
                            Spacer()
                        }
                        .card()

                        // Product header
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: product.imageURL ?? "")) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Theme.Colors.surfaceRaised.overlay(Image(systemName: "photo").foregroundStyle(Theme.Colors.textTertiary))
                                }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(product.name).font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary).lineLimit(2)
                                if let brand = product.brand, !brand.isEmpty {
                                    Text(brand).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary).lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .card()

                        // How much did you have? → scaled macros
                        if hasMacros {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("How much did you have?")
                                    .font(Theme.Fonts.headline)
                                    .foregroundStyle(Theme.Colors.textPrimary)

                                amountControl

                                HStack(spacing: 14) {
                                    macro("\(scaledCalories)", "kcal", Theme.Colors.textPrimary)
                                    macro("\(scaled(product.proteinPer100g))g", "protein", Theme.Colors.protein)
                                    macro("\(scaled(product.carbsPer100g))g", "carbs", Theme.Colors.carbs)
                                    macro("\(scaled(product.fatPer100g))g", "fat", Theme.Colors.fat)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()

                            Button {
                                Task { await logMeal() }
                            } label: {
                                Group {
                                    if isLogging { ProgressView().tint(Theme.Colors.onVolt) }
                                    else if logged { Label("Added to today", systemImage: "checkmark") }
                                    else { Label("Log \(scaledCalories) kcal to today", systemImage: "plus.circle.fill") }
                                }
                                .font(Theme.Fonts.headline)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(logged ? Theme.Colors.safe : Theme.Colors.volt)
                                .foregroundStyle(Theme.Colors.onVolt)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .disabled(isLogging || logged)
                            .pressable()
                        }

                        // All allergens present
                        if !product.productAllergenSlugs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Allergens in this product").font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                                FlowTags(items: AllergenCatalog.names(for: product.productAllergenSlugs),
                                         icon: "exclamationmark.triangle.fill", color: Theme.Colors.caution)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }

                        Text("Always verify the physical label — product recipes change and databases can lag behind.")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.Colors.volt)
                }
            }
        }
        .preferredColorScheme(nil)
    }

    private func gram(_ v: Double?) -> String { v == nil ? "—" : "\(Int(v!.rounded()))g" }

    private func macro(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.Fonts.stat(17)).foregroundStyle(color)
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Servings stepper when the label has a serving size, otherwise a grams
    /// stepper. Either way it drives the scaled macros above.
    private var amountControl: some View {
        let usingServings = servingGrams != nil
        return HStack(spacing: 14) {
            Button {
                if usingServings { servings = max(0.5, servings - 0.5) }
                else { grams = max(10, grams - 10) }
            } label: { stepIcon("minus") }
            VStack(spacing: 1) {
                if usingServings {
                    Text(servings == 1 ? "1 serving" : "\(servings.clean) servings")
                        .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(Int(effectiveGrams.rounded())) g").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                } else {
                    Text("\(Int(grams.rounded())) g")
                        .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                    Text("no serving size on label").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            Button {
                if usingServings { servings += 0.5 }
                else { grams += 10 }
            } label: { stepIcon("plus") }
        }
    }

    private func stepIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.Colors.volt)
            .frame(width: 46, height: 46)
            .background(Theme.Colors.volt.opacity(0.12), in: Circle())
    }

    private func logMeal() async {
        isLogging = true
        defer { isLogging = false }
        if !session.isDemo, let userId = session.session?.user.id {
            let record = MealLogRecord(
                id: UUID(), userId: userId, eatenAt: Date(),
                mealType: Self.mealTypeForNow(),
                name: [product.brand, product.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "),
                calories: scaledCalories,
                proteinG: Double(scaled(product.proteinPer100g)),
                carbsG: Double(scaled(product.carbsPer100g)),
                fatG: Double(scaled(product.fatPer100g)))
            do { try await Backend.client.from("meal_logs").insert(record).execute() }
            catch { print("product log failed: \(error)") }
        }
        Haptics.success()
        withAnimation { logged = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
    }

    private static func mealTypeForNow() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 4..<11: return "breakfast"
        case 11..<16: return "lunch"
        case 16..<22: return "dinner"
        default: return "snack"
        }
    }
}

private extension Double {
    /// "1.5" not "1.500000"; drops a trailing ".0".
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}

// MARK: - Camera (AVFoundation)

struct CameraScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onScan = { code in context.coordinator.emit(code) }
        return vc
    }
    func updateUIViewController(_ vc: ScannerVC, context: Context) {}

    final class Coordinator {
        let onScan: (String) -> Void
        private var lastCode: String?
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }
        func emit(_ code: String) {
            guard code != lastCode else { return }   // debounce repeats
            lastCode = code
            onScan(code)
        }
    }
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        onScan?(code)
    }
}
