import Foundation
import HealthKit
import Logger

// MARK: - Public types

public typealias ErrorHandler = () -> ()

public enum HealthCoreProviderError: Error {
    case writingError
    case readingError
    case authorizationError
}

public enum ArrayModifyType {
    case interpolate
    case shorten
    case none
}

public struct QuantityData {
    public let value: Double
    public let dateInterval: DateInterval

    public init(value: Double, dateInterval: DateInterval) {
        self.value = value
        self.dateInterval = dateInterval
    }
}

// MARK: - HealthCoreProvider

public final class HealthCoreProvider: ObservableObject {

    // MARK: - Public types
    
    public enum SampleType: Hashable {
        case quantityType(forIdentifier: HKQuantityTypeIdentifier)
        case categoryType(forIdentifier: HKCategoryTypeIdentifier, categoryValue: Int)
        case workoutType
        case seriesType(type: HKSeriesType)

        public var sampleType: HKSampleType {
            switch self {
            case .quantityType(let forIdentifier):
                return HKSampleType.quantityType(forIdentifier: forIdentifier)!
            case .categoryType(let forIdentifier, _):
                return HKSampleType.categoryType(forIdentifier: forIdentifier)!
            case .workoutType:
                return HKSampleType.workoutType()
            case .seriesType(let type):
                return type
            }
        }

        static func ==(lhs: SampleType, rhs: HKSample) -> Bool {
            switch (lhs, rhs) {
            case (.quantityType(_), rhs):
                return lhs.sampleType == rhs.sampleType
            case (let .categoryType(_, categoryValue), rhs):
                return lhs.sampleType == rhs.sampleType && (rhs as? HKCategorySample)?.value == categoryValue
            case (.workoutType, rhs):
                return lhs.sampleType == rhs.sampleType
            case (.seriesType(_), rhs):
                return lhs.sampleType == rhs.sampleType
            default:
                return false
            }
        }
    }

    public enum BundleAuthor {
        case concrete(identifiers: Set<String>)
        case all

        var bundles: Set<String> {
            switch self {
            case .concrete(let identifiers):
                return identifiers
            case .all:
                return []
            }
        }
    }

    // MARK: - Private properties

    public let healthStore: HKHealthStore = HKHealthStore()
    private let dataTypesToRead: Set<SampleType>
    private let dataTypesToWrite: Set<SampleType>

    // MARK: - Public init

    public init(
        dataTypesToRead: Set<SampleType>,
        dataTypesToWrite: Set<SampleType>
    ) {
        self.dataTypesToRead = dataTypesToRead
        self.dataTypesToWrite = dataTypesToWrite
    }

}

// MARK: - Writing data

extension HealthCoreProvider {

    // MARK: - Public methods

    /// Writes data to `HealthStore`.
    public func writeData(data: [HKSample]) async throws {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let sampleType = data.first?.sampleType,
            try await self.isWritePermissionGranted(for: sampleType)
        else {
            return
        }
        try await self.writeDataToHealthStore(data: data)
    }

    // MARK: - Private methods

    /// Checks if permission to save data in `HealthStore` was granted by user.
    private func isWritePermissionGranted(
        for objectType: HKObjectType
    ) async throws -> Bool {
        let authorizationStatus = self.healthStore.authorizationStatus(for: objectType)

        switch authorizationStatus {
        case .sharingAuthorized:
            Logger.logEvent(
                "Permission to write to HealthStore was granted by user. Successful authorization.",
                type: .success
            )
            return true
        default:
            Logger.logEvent(
                "There is no permission to write to HealthStore. Authorization status: `\(authorizationStatus.description)`. Starting authorization request...",
                type: .warning
            )
            try await self.makeAuthorizationRequest()
            if self.healthStore.authorizationStatus(for: objectType) == .sharingAuthorized {
                Logger.logEvent("Succesfull HealthStore authorization.", type: .success)
                return true
            }
            Logger.logEvent(
                "Permission to write to HealthStore was denied by user.",
                type: .warning
            )
            throw HealthCoreProviderError.authorizationError
        }
    }

    /// Saves data to `HealthStore`.
    private func writeDataToHealthStore(data: [HKSample]) async throws {
        do {
            try await self.healthStore.save(data)
        } catch {
            Logger.logEvent("Unuccessfully wrote data to HealthStore.", type: .error)
            throw HealthCoreProviderError.writingError
        }
        Logger.logEvent("Successfully wrote data to HealthStore.", type: .success)
    }

}

// MARK: - Reading data

extension HealthCoreProvider {

    // MARK: - Public methods

    /// Reads data from `HealthStore`.
    public func readData(
        sampleType: SampleType,
        dateInterval: DateInterval,
        ascending: Bool = true,
        limit: Int = HKObjectQueryNoLimit,
        author: BundleAuthor = .all,
        queryOptions: HKQueryOptions = []
    ) async throws -> [HKSample]? {
        guard
            HKHealthStore.isHealthDataAvailable(),
            try await self.isReadPermissionGranted(for: sampleType)
        else {
            return nil
        }
        return try await self.readDataFromHealthStore(
            sampleType: sampleType,
            dateInterval: dateInterval,
            ascending: ascending,
            limit: limit,
            author: author,
            queryOptions: queryOptions
        )
    }

    /// Gets the last sample from `HealthStore`.
    public func readLastData(
        for sampleType: SampleType
    ) async throws -> [HKSample]? {
        return try await self.readDataFromHealthStore(
            sampleType: sampleType,
            dateInterval: DateInterval(
                start: Date.distantPast,
                end: Date.distantFuture
            ),
            ascending: false,
            limit: 1,
            author: .all,
            queryOptions: [],
            isPermissionChecking: true
        )
    }

    // MARK: - Private methods

    /// Checks if permission to read data from `HealthStore` was granted by user.
    private func isReadPermissionGranted(for sampleType: SampleType) async throws -> Bool {
        guard
            try await !self.isAbleToReadData(
                sampleType: sampleType,
                shouldThrowError: false
            )
        else {
            return true
        }
        try await self.makeAuthorizationRequest()
        guard
            try await !self.isAbleToReadData(
                sampleType: sampleType,
                shouldThrowError: true
            )
        else {
            return true
        }
        return false
    }

    /// Tries to get the last data from `HealthStore` to determine if there is an ability to read data at all.
    private func isAbleToReadData(
        sampleType: SampleType,
        shouldThrowError: Bool
    ) async throws -> Bool {
        var lastData: [HKSample]?
        do {
            lastData = try await self.readLastData(for: sampleType)
        } catch {
            Logger.logEvent(
                "Unsuccessfully finished reading data after making authorization request with error: \(error.localizedDescription)",
                type: .error
            )
            if shouldThrowError {
                throw HealthCoreProviderError.readingError
            }
            return false
        }
        guard (lastData ?? []).isEmpty else {
            Logger.logEvent(
                "Permission to read from HealthStore was granted by user.",
                type: .success
            )
            return true
        }
        if shouldThrowError {
            Logger.logEvent(
                "There is no ability to read data from HealthStore.",
                type: .warning
            )
            throw HealthCoreProviderError.readingError
        }
        return false
    }

    /// Gets samples from `HealthStore` database using passed parameters.
    private func readDataFromHealthStore(
        sampleType: SampleType,
        dateInterval: DateInterval,
        ascending: Bool,
        limit: Int,
        author: BundleAuthor,
        queryOptions: HKQueryOptions,
        isPermissionChecking: Bool = false
    ) async throws -> [HKSample]? {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType.sampleType,
                predicate: HKQuery.predicateForSamples(
                    withStart: dateInterval.start,
                    end: dateInterval.end,
                    options: queryOptions
                ),
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: ascending)]
            ) { _, data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let samplesFiltered = isPermissionChecking ? data : data?.filter { sample in
                        (author.bundles.isEmpty || (author.bundles.contains(where: { sample.sourceRevision.source.bundleIdentifier.hasPrefix($0) }))) &&
                        sampleType == sample
                    }
                    continuation.resume(returning: samplesFiltered)
                }
            }
            self.healthStore.execute(query)
        }
    }

    public func makeQuantityData(from samples: [HKQuantitySample], unit: HKUnit) -> [QuantityData] {
        return samples.map {
            QuantityData(
                value: $0.quantity.doubleValue(for: unit),
                dateInterval: .init(start: $0.startDate, end: $0.endDate)
            )
        }
    }
}

// MARK: - Common

extension HealthCoreProvider {

    /// Makes `HealthStore` authorization request.
    private func makeAuthorizationRequest() async throws {
        do {
            try await self.healthStore.requestAuthorization(
                toShare: Set(self.dataTypesToWrite.map { $0.sampleType }),
                read: Set(self.dataTypesToRead.map { $0.sampleType })
            )
        } catch {
            Logger.logEvent("Unsuccessful HealthKit authorization request.", type: .error)
            throw HealthCoreProviderError.authorizationError
        }
    }
}

public extension HealthCoreProvider {

    func getQuantitiveDataShortened(from samples: [QuantityData]) -> [QuantityData] {
        if samples.count < 36 {
            return samples
        }
        let interpolatedSamples = self.getQuantitiveDataInterpolated(from: samples)
        var shortHeartSamples: [QuantityData] = []

        for index in stride(from: 0, to: interpolatedSamples.count, by: Int.Stride(Double.Stride(ceil(Double(interpolatedSamples.count) / 36.0)))) {
            shortHeartSamples.append(interpolatedSamples[index])
        }
        return shortHeartSamples
    }

    /// Interpolated quantitive data to handle missing values
    /// Fills data for every second
    func getQuantitiveDataInterpolated(from samples: [QuantityData]) -> [QuantityData] {
        var resultArray: [QuantityData] = []

        for (index, item) in samples.enumerated() {
            let currentRecordingValue = item.value

            if (index != 0) {
                // finds the next time in samples where a heartrate is recording by taking the time difference in seconds
                // between the current value and the value before this
                let intervalUntillNextRecording = round(item.dateInterval.start.timeIntervalSince(samples[index-1].dateInterval.end))
                let previousItemSample = samples[index-1]

                let previousRecordingValue = previousItemSample.value

                // gets the absolute value change in heart rate between current value and previous available heart rate recording
                let manipulationValue = (currentRecordingValue - previousRecordingValue) / intervalUntillNextRecording
                var manipulationValueVariation = manipulationValue

                var i = 1

                // starts interpolating the data
                while (i < Int(intervalUntillNextRecording)) {
                    let newDate = Calendar.current.date(byAdding: .second, value: i, to: previousItemSample.dateInterval.end)!
                    let newBpm = previousRecordingValue + manipulationValueVariation

                    let synthesisedSample = QuantityData(
                        value: newBpm,
                        dateInterval: .init(start: newDate, end: newDate)
                    )

                    resultArray.append(synthesisedSample)

                    manipulationValueVariation += manipulationValue
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

            let synthesisedSample = QuantityData(
                value: currentRecordingValue,
                dateInterval: item.dateInterval)

            resultArray.append(synthesisedSample)
        }
        return resultArray
    }

}
