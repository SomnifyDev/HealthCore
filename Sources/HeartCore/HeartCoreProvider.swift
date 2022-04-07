import Foundation
import HealthCore
import HealthKit
import Logger

// MARK: - Public types

public typealias HRVIndicatorValue = Double

public enum HeartCoreProviderError: Error {
    case heartbeatSeriesQueryError(Error)
}

public struct HeartbeatData {
    public let value: Double
    public let recordingDate: Date
}

public struct HeartbeatSeries {
    public let timeSinceSeriesStart: TimeInterval
    public let precededByGap: Bool

    public init(
        timeSinceSeriesStart: TimeInterval,
        precededByGap: Bool
    ) {
        self.timeSinceSeriesStart = timeSinceSeriesStart
        self.precededByGap = precededByGap
    }
}

// MARK: - HeartCoreProvider

public final class HeartCoreProvider: ObservableObject {
    
    // MARK: - Private properties
    
    private let healthCoreProvider: HealthCoreProvider
    private let healthStore: HKHealthStore = HKHealthStore()
    
    // MARK: - Init
    
    public init(healthCoreProvider: HealthCoreProvider) {
        self.healthCoreProvider = healthCoreProvider
    }
    
    // MARK: - Public methods
    
    /// Returns heartbeat series (array of `timeSinceSeriesStart` aka `Double`), that are calculating when the Apple Watch's sensor tracks heart rate variability
    ///
    /// This method guarantees that returning array, if it is not nil, will contain elements.
    public func getHeartbeatSeries(during dateInterval: DateInterval) async throws -> [[HeartbeatSeries]]? {
        try await fetchHeartbeatSeries(during: dateInterval)
    }

    /// Returns heartbeat series (array of `HeartbeatSeries`), that contains `timeSinceSeriesStart` values that are calculating when the Apple Watch's sensor tracks heart rate variability
    ///
    /// This methods guarantees that returning array, if it is not nil, will contain at least one element.
    public func getLastHeartbeatSeries() async throws -> [HeartbeatSeries]? {
        try await fetchLastHeartbeatSeries()
    }
    
    /// Returns simple heartbeat data of the user with it's (measurment) `value` and `recordingDate`
    public func getHeartbeatData(
        dateInterval: DateInterval,
        ascending: Bool = true,
        limit: Int = HKObjectQueryNoLimit,
        author: HealthCoreProvider.BundleAuthor = .all,
        queryOptions: HKQueryOptions = [],
        shouldInterpolate: Bool = false
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
        return shouldInterpolate
        ? self.getHeartRateDataInterpolated(from: fetchHeartbeatData(from: heartbeatData))
        : fetchHeartbeatData(from: heartbeatData)
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
    
    private func fetchLastHeartbeatSeries() async throws -> [HeartbeatSeries]? {
        guard
            let samples = try await self.healthCoreProvider.readLastData(for: .seriesType(type: .heartbeat())),
            let lastSample = samples.last as? HKHeartbeatSeriesSample
        else {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            var result: [HeartbeatSeries] = []
            let query = HKHeartbeatSeriesQuery(heartbeatSeries: lastSample) { query, timeSinceSeriesStart, precededByGap, done, error in
                if let error = error {
                    Logger.logEvent("Continuation resumes with error: \(error.localizedDescription)", type: .error)
                    continuation.resume(throwing: HeartCoreProviderError.heartbeatSeriesQueryError(error))
                }
                if done {
                    Logger.logEvent("Continuation resumes with some result. \nResult: \(String(describing: result))\n", type: .success)
                    continuation.resume(returning: result.isEmpty ? nil : result)
                    return
                }
                result.append(HeartbeatSeries(timeSinceSeriesStart: timeSinceSeriesStart, precededByGap: precededByGap))
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchHeartbeatSeries(during dateInterval: DateInterval) async throws -> [[HeartbeatSeries]]? {
        guard
            let samples = try await self.healthCoreProvider.readData(
                sampleType: .seriesType(type: .heartbeat()),
                dateInterval: dateInterval
            ) as? [HKHeartbeatSeriesSample]
        else {
            return nil
        }
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            var errorHandler: (didCatchError: Bool, error: Error?) = (false, nil)
            var result: [[HeartbeatSeries]] = []
            for index in 0..<samples.count {
                let sample = samples[index]
                var localResult: [HeartbeatSeries] = []
                let sampleQuery = HKHeartbeatSeriesQuery(heartbeatSeries: sample) { query, timeSinceSeriesStart, precededByGap, done, error in
                    if let error = error {
                        Logger.logEvent("Error occurred during Heartbeat Query with localized description: \(error.localizedDescription)", type: .error)
                        errorHandler = (true, error)
                    }
                    if done {
                        result.append(localResult)
                        if index == samples.count - 1 {
                            // [NOTE] - Почему здесь необходима такая конструкция и почему бы просто не бросить ошибку в блоке проверки на ошибку?
                            //
                            // Причина в том, что поверх `HKHeartbeatSeriesQuery`, которая сама по себе запускается каждый раз до тех пор,
                            // пока не достанет все значения `beat to beat measurments`, наложен цикл по всем имеющимся циклам.
                            // Это приводит к тому, что при неправильных действиях разработчика `continuation` может вызвать функцию `resume`
                            // более одного раза, что приведет к крэшу.
                            //
                            // Так что любой вызов `continuation.resume(...)` в данном методе происходит только при самый последней итерациях всего.
                            if errorHandler.didCatchError {
                                let error = errorHandler.error.unsafelyUnwrapped
                                Logger.logEvent("Continuation resumes with error: \(error.localizedDescription)", type: .error)
                                continuation.resume(throwing: HeartCoreProviderError.heartbeatSeriesQueryError(error))
                            }
                            Logger.logEvent("Continuation resumes with some result. \nResult: \(String(describing: result))\n", type: .success)
                            continuation.resume(returning: result.isEmpty ? nil : result)
                        }
                    }
                    localResult.append(HeartbeatSeries(timeSinceSeriesStart: timeSinceSeriesStart, precededByGap: precededByGap))
                }
                self?.healthStore.execute(sampleQuery)
            }
        }
    }
    
    private func fetchHeartbeatData(from samples: [HKQuantitySample]) -> [HeartbeatData] {
        return samples.map {
            HeartbeatData(
                value: $0.quantity.doubleValue(for: .countMin()),
                recordingDate: $0.startDate
            )
        }
    }

    /// Interpolated Heart rate data to handle missing values
    /// Fills data for every second
    private func getHeartRateDataInterpolated(from samples: [HeartbeatData]) -> [HeartbeatData] {
        var heartBeatArray: [HeartbeatData] = []

            for (index, item) in samples.enumerated() {


                // converts HR recording into double
                let currentHeartBeatRecording = item.value

                // ignores first value in the array for out of bounds error
                if (index != 0) {

                    // finds the next time in self.heartSamples where a heartrate is recording by taking the time difference in seconds
                    // between the current value and the value before this
                    let intervalUntillNextRecording = round(item.recordingDate.timeIntervalSince(samples[index-1].recordingDate))
                    let previousItemSample = samples[index-1]
                    // converts HR recording into double
                    let previousHeartBeatRecording = previousItemSample.value

                    // gets the absolute value change in heart rate between current value and previous available heart rate recording
                    let manipulationHeartBeatValue = (currentHeartBeatRecording - previousHeartBeatRecording)/intervalUntillNextRecording
                    var manipulationHeartBeatValueVariation = manipulationHeartBeatValue
                    let calendar = Calendar.current

                    var i = 1

                    // starts interpolating the data
                    while (i < Int(intervalUntillNextRecording)) {

                        // creates a new date.
                        let newDate = calendar.date(byAdding: .second, value: i, to: previousItemSample.recordingDate)

                        // adds the HR increase amount to the previous value
                        let newBpm = previousHeartBeatRecording + manipulationHeartBeatValueVariation

                        let synthesisedHeartSample = HeartbeatData(
                            value: newBpm,
                            recordingDate: newDate!)

                        heartBeatArray.append(synthesisedHeartSample)
                        manipulationHeartBeatValueVariation += manipulationHeartBeatValue
                        i+=1

                        /* Example:
                         Say a BPM was recorded at time 11:00:01am of 70bpm
                         And the next BPM was recorded at time 11:00:05am of 75bpm (which is 4 seconds later)
                         The bpm has increased by 5
                         therefore 5 - 1 = 4, there are 3 spaces to fill, so 4/3 = 1.33
                         11:01:01am = 70
                         11:01:02am = 71.3
                         11:01:03am = 72.6
                         11:01:04am = 73.9
                         11:01:05am = 75
                        */
                    }

                }

                let synthesisedHeartSample = HeartbeatData(
                    value: currentHeartBeatRecording,
                    recordingDate: item.recordingDate)

                heartBeatArray.append(synthesisedHeartSample)
            }

            // Watch produces inauthentic results when calebrating: ignore the first 5 values
            if (heartBeatArray.count > 5) {
                heartBeatArray.removeFirst(5)
            }
            return heartBeatArray
        }
}
