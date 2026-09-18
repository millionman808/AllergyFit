import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Comprehensive HealthKit & Wearable sync manager.
/// Reads workouts, runs, active energy, steps, and heart rate (from Apple Watch, Fitbit, Garmin, Strava, etc.).
/// Writes dietary energy and hydration back to Apple Health.
@MainActor
final class HealthManager: ObservableObject {
    static let shared = HealthManager()

    @Published var connected = UserDefaults.standard.bool(forKey: "health.connected")
    @Published var available = false
    @Published var todayWorkouts: [HealthWorkoutSummary] = []
    @Published var todayActiveEnergy: Int = 0
    @Published var todaySteps: Int = 0
    @Published var currentHeartRate: Int? = nil
    @Published var restingHeartRate: Int? = nil
    @Published var isLoading = false

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    private var readTypes: Set<HKObjectType> {
        var s: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { s.insert(energy) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { s.insert(steps) }
        if let distRun = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { s.insert(distRun) }
        if let distCyc = HKObjectType.quantityType(forIdentifier: .distanceCycling) { s.insert(distCyc) }
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { s.insert(hr) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { s.insert(rhr) }
        if let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) { s.insert(flow) }
        return s
    }

    private var writeTypes: Set<HKSampleType> {
        var s: Set<HKSampleType> = []
        if let dietary = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { s.insert(dietary) }
        if let protein = HKObjectType.quantityType(forIdentifier: .dietaryProtein) { s.insert(protein) }
        if let carbs = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) { s.insert(carbs) }
        if let fat = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) { s.insert(fat) }
        if let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) { s.insert(water) }
        return s
    }
    #endif

    init() {
        #if canImport(HealthKit)
        available = HKHealthStore.isHealthDataAvailable()
        #endif
        if connected {
            Task { await refreshTodayHealth() }
            startBackgroundObserver()
        }
    }

    @discardableResult
    func connect() async -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            connected = true
            UserDefaults.standard.set(true, forKey: "health.connected")
            startBackgroundObserver()
            await refreshTodayHealth()
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
        todayWorkouts = []
        todayActiveEnergy = 0
        todaySteps = 0
        currentHeartRate = nil
        restingHeartRate = nil
    }

    // MARK: - Query Engine

    func refreshTodayHealth() async {
        #if canImport(HealthKit)
        guard connected, available else { return }
        isLoading = true
        defer { isLoading = false }

        async let workouts = fetchTodayWorkouts()
        async let energy = fetchTodayActiveEnergy()
        async let steps = fetchTodaySteps()
        async let hr = fetchHeartRates()

        let (w, e, s, h) = await (workouts, energy, steps, hr)
        self.todayWorkouts = w
        self.todayActiveEnergy = e
        self.todaySteps = s
        self.currentHeartRate = h.current
        self.restingHeartRate = h.resting

        if CycleManager.shared.state.isEnabled {
            if let latestCycleStart = await fetchLatestMenstrualCycleStart() {
                CycleManager.shared.updateLastPeriodStartDate(latestCycleStart, syncedFromHealth: true)
            }
        }
        #endif
    }

    #if canImport(HealthKit)
    func fetchLatestMenstrualCycleStart() async -> Date? {
        guard let flowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: flowType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.startDate)
            }
            store.execute(query)
        }
    }

    func fetchTodayWorkouts() async -> [HealthWorkoutSummary] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                let summaries: [HealthWorkoutSummary] = workouts.map { w in
                    let activityName = Self.readableActivity(w.workoutActivityType)
                    let sourceName = w.sourceRevision.source.name
                    let durationMins = max(1, Int(w.duration / 60))
                    let calories = Int(w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
                    let distance = w.totalDistance?.doubleValue(for: .meter())

                    return HealthWorkoutSummary(
                        id: w.uuid,
                        title: activityName,
                        activityType: Self.slugForActivity(w.workoutActivityType),
                        startDate: w.startDate,
                        durationMinutes: durationMins,
                        caloriesBurned: calories,
                        distanceMeters: distance,
                        avgHeartRate: nil,
                        source: sourceName,
                        icon: HealthWorkoutSummary.icon(for: Self.slugForActivity(w.workoutActivityType))
                    )
                }
                continuation.resume(returning: summaries)
            }
            store.execute(query)
        }
    }

    func fetchTodayActiveEnergy() async -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: Int(kcal.rounded()))
            }
            store.execute(query)
        }
    }

    func fetchTodaySteps() async -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let steps = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps.rounded()))
            }
            store.execute(query)
        }
    }

    func fetchHeartRates() async -> (current: Int?, resting: Int?) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return (nil, nil) }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let latestHR: Int? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: Int(bpm.rounded()))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            store.execute(query)
        }

        var restingHR: Int? = nil
        if let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            restingHR = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: rhrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                    if let sample = samples?.first as? HKQuantitySample {
                        let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                        continuation.resume(returning: Int(bpm.rounded()))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
                store.execute(query)
            }
        }

        return (latestHR, restingHR)
    }

    // MARK: - Write Engine

    @discardableResult
    func writeDietaryNutrition(calories: Int, proteinG: Double, carbsG: Double, fatG: Double, date: Date = Date()) async -> Bool {
        guard connected, available else { return false }
        var samples: [HKQuantitySample] = []

        if let calType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed), calories > 0 {
            samples.append(HKQuantitySample(type: calType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories)), start: date, end: date))
        }
        if let pType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein), proteinG > 0 {
            samples.append(HKQuantitySample(type: pType, quantity: HKQuantity(unit: .gram(), doubleValue: proteinG), start: date, end: date))
        }
        if let cType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates), carbsG > 0 {
            samples.append(HKQuantitySample(type: cType, quantity: HKQuantity(unit: .gram(), doubleValue: carbsG), start: date, end: date))
        }
        if let fType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal), fatG > 0 {
            samples.append(HKQuantitySample(type: fType, quantity: HKQuantity(unit: .gram(), doubleValue: fatG), start: date, end: date))
        }

        guard !samples.isEmpty else { return false }
        return await withCheckedContinuation { continuation in
            store.save(samples) { success, error in
                if let error { print("write dietary error: \(error)") }
                continuation.resume(returning: success)
            }
        }
    }

    @discardableResult
    func writeWater(milliliters: Double, date: Date = Date()) async -> Bool {
        guard connected, available, milliliters > 0 else { return false }
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return false }
        let sample = HKQuantitySample(type: waterType, quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters), start: date, end: date)

        return await withCheckedContinuation { continuation in
            store.save(sample) { success, error in
                if let error { print("write water error: \(error)") }
                continuation.resume(returning: success)
            }
        }
    }

    private func startBackgroundObserver() {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let query = HKObserverQuery(sampleType: energyType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                await self?.refreshTodayHealth()
            }
        }
        store.execute(query)
        self.observerQuery = query
    }

    private static func readableActivity(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength Training"
        case .swimming: return "Swimming"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .highIntensityIntervalTraining: return "HIIT"
        case .crossTraining: return "CrossFit"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        default: return "Workout"
        }
    }

    private static func slugForActivity(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "running"
        case .cycling: return "cycling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "lifting"
        case .swimming: return "swimming"
        case .walking, .hiking: return "walking"
        case .highIntensityIntervalTraining, .crossTraining: return "hiit"
        case .yoga: return "yoga"
        default: return "other"
        }
    }
    #else
    func refreshTodayHealth() async {}
    func fetchLatestMenstrualCycleStart() async -> Date? { nil }
    private func startBackgroundObserver() {}
    #endif
}
