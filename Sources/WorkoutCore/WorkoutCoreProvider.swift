import Foundation
import HealthCore
import HealthKit
import Logger

// MARK: - WorkoutCoreProvider

public final class WorkoutCoreProvider: ObservableObject {

    // MARK: - Private properties

    private let healthCoreProvider: HealthCoreProvider

    // MARK: - Init

    public init(healthCoreProvider: HealthCoreProvider) {
        self.healthCoreProvider = healthCoreProvider
    }

    // MARK: - Public methods

    /// Returns sample of workout data of the user
    public func getWorkoutData(
        dateInterval: DateInterval,
        ascending: Bool = true,
        limit: Int = HKObjectQueryNoLimit,
        author: HealthCoreProvider.BundleAuthor = .all,
        queryOptions: HKQueryOptions = []
    ) async throws -> [WorkoutData]? {
        guard
            let workoutSamples = try await self.healthCoreProvider.readData(
                sampleType: .workoutType,
                dateInterval: dateInterval,
                ascending: ascending,
                limit: limit,
                author: author,
                queryOptions: queryOptions
            )  as? [HKWorkout]
        else {
            return nil
        }

        return workoutSamples.map { self.getWorkoutData(from: $0) }
    }

    /// Returns last sample of workout data of the user
    public func getLastWorkoutData() async throws -> WorkoutData? {
        guard
            let workoutSamples = try await self.healthCoreProvider.readData(
                sampleType: .workoutType,
                dateInterval: .init(start: .distantPast, end: Date())
            )  as? [HKWorkout],
            let lastSample = workoutSamples.last
        else {
            return nil
        }

        return self.getWorkoutData(from: lastSample)
    }

    // MARK: - Private methods

    private func getWorkoutData(from sample: HKWorkout) -> WorkoutData {
        return WorkoutData(
            workoutActivityType: sample.workoutActivityType,
            dateInterval: .init(start: sample.startDate, end: sample.endDate),
            duration: sample.duration,
            totalDistance: sample.totalDistance,
            totalEnergyBurned: sample.totalEnergyBurned,
            workoutEvents: sample.workoutEvents,
            totalFlightsClimbed: sample.totalFlightsClimbed,
            totalSwimmingStrokeCount: sample.totalSwimmingStrokeCount
        )
    }
}

