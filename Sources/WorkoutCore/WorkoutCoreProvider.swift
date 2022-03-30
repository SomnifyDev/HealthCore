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

    /// Returns simple workout data of the user
    public func getWorkoutData(
        dateInterval: DateInterval,
        ascending: Bool = true,
        limit: Int = HKObjectQueryNoLimit,
        author: HealthCoreProvider.BundleAuthor = .all,
        queryOptions: HKQueryOptions = []
    ) async throws -> [WorkoutData]? {
        guard
            let workoutData = try await self.healthCoreProvider.readData(
                sampleType: .workoutType,
                dateInterval: dateInterval,
                ascending: ascending,
                limit: limit,
                author: author,
                queryOptions: queryOptions
            )
        else {
            return nil
        }

        return self.getWorkoutData(from: workoutData as? [HKWorkout])
    }

    private func getWorkoutData(from samples: [HKWorkout]?) -> [WorkoutData]? {
        return samples?.map {
            WorkoutData(
                workoutActivityType: $0.workoutActivityType,
                dateInterval: .init(start: $0.startDate, end: $0.endDate),
                duration: $0.duration,
                totalDistance: $0.totalDistance,
                totalEnergyBurned: $0.totalEnergyBurned,
                workoutEvents: $0.workoutEvents,
                totalFlightsClimbed: $0.totalFlightsClimbed,
                totalSwimmingStrokeCount: $0.totalSwimmingStrokeCount
            )
        }
    }
    
}
