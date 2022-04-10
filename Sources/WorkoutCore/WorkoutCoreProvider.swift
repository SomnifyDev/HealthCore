import Foundation
import HealthCore
import HealthKit
import Logger
import CoreLocation
import HeartCore

// MARK: - WorkoutCoreProvider

public final class WorkoutCoreProvider: ObservableObject {

    // MARK: - Private properties

    private let healthCoreProvider: HealthCoreProvider
    private let heartCoreProvider: HeartCoreProvider
    // MARK: - Init

    public init(healthCoreProvider: HealthCoreProvider) {
        self.healthCoreProvider = healthCoreProvider
        self.heartCoreProvider = HeartCoreProvider(healthCoreProvider: self.healthCoreProvider)
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
            )  as? [HKWorkout],
            !workoutSamples.isEmpty
        else {
            return nil
        }

        var workoutData: [WorkoutData] = []
        for workoutSample in workoutSamples {
            workoutData.append(await self.getWorkoutData(from: workoutSample))
        }
        return workoutData
    }

    private func getWorkoutRouteDate(for workout: HKWorkout) async throws -> [WorkoutRouteData]? {
        guard let workoutRoutes = try await self.getWorkoutRoute(for: workout),
              !workoutRoutes.isEmpty else {
                  return nil
              }

        // second async call
        var locations: [WorkoutRouteData] = []
        for workoutRoute in workoutRoutes {
            let seriesLocations = try await self.geLocationData(route: workoutRoute)
            locations.append(
                WorkoutRouteData(
                    dateInterval: DateInterval(start: workoutRoute.startDate, end: workoutRoute.endDate),
                    locations: seriesLocations
                )
            )
        }
        // This block may be called multiple times.
        return locations
    }

    /// This function will asynchronously read the route for the passed in `workout`.
    /// There can be multiple routes for every workout.
    /// - Parameter workout: The workout for which the route is needed
    /// - Returns: The routes objects for `workout`
    private func getWorkoutRoute(for workout: HKWorkout) async throws -> [HKWorkoutRoute]? {
        let byWorkout = HKQuery.predicateForObjects(from: workout)

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            self.healthCoreProvider.healthStore.execute(HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(), predicate: byWorkout, anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: { (query, samples, deletedObjects, anchor, error) in
                if let hasError = error {
                    continuation.resume(throwing: hasError)
                    return
                }

                guard let samples = samples else {
                    return
                }

                continuation.resume(returning: samples)
            }))
        }

        guard let workouts = samples as? [HKWorkoutRoute] else {
            return nil
        }

        return workouts
    }

    /// This function will asynchronously read the location data for the passed in `route`
    /// - Parameter workoutRoute: The route for which the location data is needed
    /// - Returns: The location data fot `route`
    private func geLocationData(route workoutRoute: HKWorkoutRoute) async throws ->  [CLLocation] {
        return try await withCheckedThrowingContinuation { continuation in
            var allLocations = [CLLocation]()
            let query = HKWorkoutRouteQuery(route: workoutRoute) { (query, locationsOrNil, done, errorOrNil) in

                // This block may be called multiple times.
                if let error = errorOrNil {
                    return continuation.resume(with: .failure(error))
                }

                guard done else {
                    assert(locationsOrNil != nil)
                    return allLocations.append(contentsOf: locationsOrNil!)
                }

                return continuation.resume(with: .success(allLocations))
            }

            self.healthCoreProvider.healthStore.execute(query)
        }
    }

    /// Returns last sample of workout data of the user
    public func getLastWorkoutData() async throws -> WorkoutData? {
        guard
            let samples = try await self.healthCoreProvider.readLastData(for: .workoutType),
            let lastSample = samples.last as? HKWorkout
        else {
            return nil
        }

        return await self.getWorkoutData(from: lastSample)
    }

    // MARK: - Private methods

    private func getWorkoutData(from sample: HKWorkout) async -> WorkoutData {
        var routeData: [WorkoutRouteData]?
        var heartInterpolatedData: [QuantityData]?

        do {
            routeData = try await self.getWorkoutRouteDate(for: sample)
            heartInterpolatedData = try await self.heartCoreProvider.getHeartbeatData(
                dateInterval: .init(start: sample.startDate, end: sample.endDate),
                arrayModification: .interpolate
            )

        } catch {
            routeData = nil
            heartInterpolatedData = nil
        }
        return WorkoutData(
            workoutActivityType: sample.workoutActivityType,
            dateInterval: .init(start: sample.startDate, end: sample.endDate),
            duration: sample.duration,
            totalDistance: sample.totalDistance,
            routeData: routeData,
            heartInterpolatedData: heartInterpolatedData,
            totalEnergyBurned: sample.totalEnergyBurned,
            workoutEvents: sample.workoutEvents,
            totalFlightsClimbed: sample.totalFlightsClimbed,
            totalSwimmingStrokeCount: sample.totalSwimmingStrokeCount,
            rawSample: sample
        )
    }


}
