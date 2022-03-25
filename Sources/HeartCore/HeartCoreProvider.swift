import Foundation
import HealthCore
import HealthKit
import Logger

// MARK: - Public types

public typealias HeartbeatSeries = [Double]
public typealias HRVIndicatorValue = Double

public enum HeartbeatSeriesGettingDataStrategy {
    case last
    case period(DateInterval)
}

public enum HeartCoreProviderError: Error {
    case heartbeatSeriesQueryError(Error)
}

public struct HeartbeatData {
    public let value: Double
    public let recordingDate: Date
}

// MARK: - HeartCoreProvider

public final class HeartCoreProvider {
    
    // MARK: - Private properties
    
    private let healthCoreProvider: HealthCoreProvider
    private let healthStore: HKHealthStore = HKHealthStore()
    
    // MARK: - Init
    
    public init(healthCoreProvider: HealthCoreProvider) {
        self.healthCoreProvider = healthCoreProvider
    }
    
    // MARK: - Public methods
    
    /// Returns heartbeat series (array of `timeSinceSeriesStart` aka `Double`), that are calculating when the Apple Watch's sensor tracks heart rate variability
    public func getHeartbeatSeries(
        _ strategy: HeartbeatSeriesGettingDataStrategy
    ) async throws -> HeartbeatSeries? {
        switch strategy {
        case .last:
            return try await self.getLastHeartbeatSeries()
        case .period(let dateInterval):
            return try await self.getHeartbeatSeries(during: dateInterval)
        }
    }
    
    /// Returns simple heartbeat data of the user with it's (measurment) `value` and `recordingDate`
    public func getHeartbeatData(
        dateInterval: DateInterval,
        ascending: Bool = true,
        limit: Int = HKObjectQueryNoLimit,
        author: HealthCoreProvider.BundleAuthor = .all,
        queryOptions: HKQueryOptions = []
    ) async throws -> [HeartbeatData]? {
        guard
            let heartbeatData = try await self.healthCoreProvider.readData(
                sampleType: .quantityType(forIdentifier: .heartRate),
                dateInterval: dateInterval,
                ascending: ascending,
                limit: limit,
                author: author,
                queryOptions: queryOptions
            ) as? [HKQuantitySample]
        else {
            return nil
        }
        return self.getHeartbeatData(from: heartbeatData)
    }
    
    /// Returns heart rate variability indicator during the concrete period of time
    public func getHeartRateVariabilityData(
        dateInterval: DateInterval,
        ascending: Bool = true,
        limit: Int = HKObjectQueryNoLimit,
        author: HealthCoreProvider.BundleAuthor = .all,
        queryOptions: HKQueryOptions = []
    ) async throws -> [HRVIndicatorValue]? {
        guard
            let samples = try await self.healthCoreProvider.readData(
                sampleType: .quantityType(forIdentifier: .heartRateVariabilitySDNN),
                dateInterval: dateInterval
            ) as? [HKQuantitySample]
        else {
            return nil
        }
        return samples.map { $0.quantity.doubleValue(for: .secondUnit(with: .milli)) }
    }
    
    // MARK: - Private methods
    
    private func getLastHeartbeatSeries() async throws -> HeartbeatSeries? {
        guard
            let samples = try await self.healthCoreProvider.readData(
                sampleType: .seriesType(type: .heartbeat()),
                dateInterval: .init(start: .distantPast, end: Date())
            ),
            let lastSample = samples.last as? HKHeartbeatSeriesSample
        else {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            var result: HeartbeatSeries = []
            let query = HKHeartbeatSeriesQuery(heartbeatSeries: lastSample) { query, timeSinceSeriesStart, precededByGap, done, error in
                if let error = error {
                    Logger.logEvent("Error occurred during Heartbeat Query with localized description: \(error.localizedDescription)", type: .error)
                    continuation.resume(throwing: HeartCoreProviderError.heartbeatSeriesQueryError(error))
                }
                if done {
                    continuation.resume(returning: result.isEmpty ? nil : result)
                    return
                }
                result.append(timeSinceSeriesStart)
            }
            self.healthStore.execute(query)
        }
    }
    
    private func getHeartbeatSeries(during dateInterval: DateInterval) async throws -> HeartbeatSeries? {
        guard
            let samples = try await self.healthCoreProvider.readData(
                sampleType: .seriesType(type: .heartbeat()),
                dateInterval: dateInterval
            ) as? [HKHeartbeatSeriesSample]
        else {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            var result: HeartbeatSeries = []
            samples.forEach { sample in
                let concreteSampleQuery = HKHeartbeatSeriesQuery(heartbeatSeries: sample) { query, timeSinceSeriesStart, precededByGap, done, error in
                    if let error = error {
                        Logger.logEvent("Error occurred during Heartbeat Query with localized description: \(error.localizedDescription)", type: .error)
                        continuation.resume(throwing: HeartCoreProviderError.heartbeatSeriesQueryError(error))
                    }
                    if done {
                        continuation.resume(returning: result.isEmpty ? nil : result)
                        return
                    }
                    result.append(timeSinceSeriesStart)
                }
                self.healthStore.execute(concreteSampleQuery)
            }
        }
    }
    
    private func getHeartbeatData(from samples: [HKQuantitySample]) -> [HeartbeatData] {
        return samples.map {
            HeartbeatData(
                value: $0.quantity.doubleValue(for: .countMin()),
                recordingDate: $0.startDate
            )
        }
    }
    
}
