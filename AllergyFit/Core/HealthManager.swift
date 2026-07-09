import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Thin HealthKit wrapper — reads workouts + active energy, writes dietary energy.
@MainActor
final class HealthManager: ObservableObject {
    @Published var connected = UserDefaults.standard.bool(forKey: "health.connected")
    @Published var available = false

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var s: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { s.insert(energy) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { s.insert(steps) }
        return s
    }
    private var writeTypes: Set<HKSampleType> {
        var s: Set<HKSampleType> = []
        if let dietary = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { s.insert(dietary) }
        return s
    }
    #endif

    init() {
        #if canImport(HealthKit)
        available = HKHealthStore.isHealthDataAvailable()
        #endif
    }

    @discardableResult
    func connect() async -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            connected = true
            UserDefaults.standard.set(true, forKey: "health.connected")
            return true
        } catch {
            print("health auth failed: \(error)")
            return false
        }
        #else
        return false
        #endif
    }

    func disconnect() {
        connected = false
        UserDefaults.standard.set(false, forKey: "health.connected")
    }
}
