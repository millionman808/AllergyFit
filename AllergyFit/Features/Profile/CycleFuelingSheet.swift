import SwiftUI

/// SafeFuel "Hormone Fuel Concierge" — Cycle-Aware Athletic Periodization Sheet.
/// Provides scientific menstrual cycle phase tracking, HealthKit sync,
/// and dynamic luteal-phase caloric adjustments in the Old Money Athletic Club aesthetic.
struct CycleFuelingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cycleManager = CycleManager.shared
    @ObservedObject private var health = HealthManager.shared

    @State private var isEnabled: Bool
    @State private var cycleLength: Int
    @State private var lastPeriodDate: Date
    @State private var selectedManualPhase: CyclePhase?
    @State private var isSyncingHealth = false

    init() {
        let state = CycleManager.shared.state
        _isEnabled = State(initialValue: state.isEnabled)
        _cycleLength = State(initialValue: state.cycleLengthDays)
        _lastPeriodDate = State(initialValue: state.lastPeriodStartDate)
        _selectedManualPhase = State(initialValue: state.manualOverridePhase)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heroCard
                        enableToggleCard

                        if isEnabled {
                            healthSyncCard
                            currentStatusCard
                            cycleParametersCard
                            phaseGuideSection
                        }
                    }
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Hormone Fuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.volt)
                }
            }
        }
    }

    // MARK: - Hero Header

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.antiqueBrass)
                Text("EST. 2026 • ATHLETIC PHYSIOLOGY CONCIERGE")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .tracking(1.4)
                    .foregroundStyle(Theme.Colors.antiqueBrass)
            }

            Text("Cycle-Aware Fueling")
                .font(Theme.Fonts.display(24))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Dynamic caloric & macronutrient periodization synchronized with your hormonal phases to optimize power, protect lean muscle, and eliminate craving guilt.")
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    // MARK: - Enable Toggle

    private var enableToggleCard: some View {
        HStack(spacing: 14) {
            Image(systemName: isEnabled ? "flame.circle.fill" : "flame.circle")
                .font(.title)
                .foregroundStyle(isEnabled ? Theme.Colors.volt : Theme.Colors.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Active Periodization")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(isEnabled ? "Caloric targets adapt to your cycle phase" : "Static daily caloric targets")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(Theme.Colors.volt)
        }
        .card()
    }

    // MARK: - Apple Health Sync Card

    private var healthSyncCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(Theme.Colors.danger)
                .frame(width: 38, height: 38)
                .background(Theme.Colors.danger.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health Menstrual Sync")
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(cycleManager.isHealthKitSynced ? "Auto-synced from Apple Health records" : "Syncs cycle days from Apple Watch or Health app")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Button {
                Task {
                    isSyncingHealth = true
                    if !health.connected {
                        await health.connect()
                    }
                    if let start = await health.fetchLatestMenstrualCycleStart() {
                        lastPeriodDate = start
                        selectedManualPhase = nil
                        cycleManager.updateLastPeriodStartDate(start, syncedFromHealth: true)
                    }
                    isSyncingHealth = false
                }
            } label: {
                if isSyncingHealth {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(cycleManager.isHealthKitSynced ? "Synced" : "Sync")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(cycleManager.isHealthKitSynced ? Theme.Colors.safe : Theme.Colors.volt)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.Colors.surfaceRaised, in: Capsule())
                }
            }
        }
        .card()
    }

    // MARK: - Current Status

    private var currentStatusCard: some View {
        let activePhase = selectedManualPhase ?? cycleManager.state.activePhase()
        let day = cycleManager.state.currentDay()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: activePhase.icon)
                        .foregroundStyle(activePhase.accentColor)
                    Text("ACTIVE PHASE")
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .tracking(1.2)
                        .foregroundStyle(activePhase.accentColor)
                }

                Spacer()

                Text("Day \(day) of \(cycleLength)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            HStack(spacing: 12) {
                Text(activePhase.title)
                    .font(Theme.Fonts.display(26))
                    .foregroundStyle(Theme.Colors.textPrimary)

                if activePhase.caloricAdjustment > 0 {
                    Text("+\(activePhase.caloricAdjustment) kcal")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.onVolt)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.volt, in: Capsule())
                }

                if activePhase.proteinAdjustment > 0 {
                    Text("+\(activePhase.proteinAdjustment)g protein")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.onVolt)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.saddleLeather, in: Capsule())
                }
            }

            Text(activePhase.coachingSummary)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)

            Divider().padding(.vertical, 4)

            Text("Override Active Phase Manually")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)

            HStack(spacing: 8) {
                ForEach(CyclePhase.allCases) { phase in
                    let isSelected = activePhase == phase
                    Button {
                        selectedManualPhase = phase
                        cycleManager.setManualPhase(phase)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: phase.icon)
                                .font(.system(size: 14))
                            Text(phase.title)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? phase.accentColor : Theme.Colors.surfaceRaised)
                        .foregroundStyle(isSelected ? Color.white : Theme.Colors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Cycle Parameters

    private var cycleParametersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CYCLE PARAMETERS")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .tracking(1.2)
                .foregroundStyle(Theme.Colors.antiqueBrass)

            Stepper(value: $cycleLength, in: 21...35) {
                HStack {
                    Text("Typical Cycle Length")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text("\(cycleLength) days")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.volt)
                }
            }

            DatePicker("Last Period Started", selection: $lastPeriodDate, displayedComponents: .date)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .tint(Theme.Colors.volt)
        }
        .card()
    }

    // MARK: - Phase Science Guide

    private var phaseGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THE ATHLETIC PERIODIZATION BLUEPRINT")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .tracking(1.2)
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.leading, 4)

            ForEach(CyclePhase.allCases) { phase in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(phase.accentColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(phase.title)
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Text(phase.dayRangeDescription)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)

                            Spacer()

                            if phase.caloricAdjustment > 0 {
                                Text("+\(phase.caloricAdjustment) kcal")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(phase.accentColor)
                            }
                        }

                        Text(phase.coachingSummary)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .card()
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        cycleManager.state.isEnabled = isEnabled
        cycleManager.state.cycleLengthDays = cycleLength
        cycleManager.state.lastPeriodStartDate = lastPeriodDate
        cycleManager.state.manualOverridePhase = selectedManualPhase
        dismiss()
    }
}
