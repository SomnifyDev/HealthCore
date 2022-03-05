import Foundation
import HealthKit
import Logger

// MARK: - Public types

public typealias ErrorHandler = () -> ()

// MARK: - HealthCoreProvider

public final class HealthCoreProvider {
    public enum HealthType: String, CaseIterable {
        case energy, heart, asleep, inbed, respiratory

        public var hkValue: HKSampleType {
            switch self {
            case .energy:
                return HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!
            case .heart:
                return HKSampleType.quantityType(forIdentifier: .heartRate)!
            case .asleep:
                return HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
            case .inbed:
                return HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
            case .respiratory:
                return HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
            }
        }

        public var metaDataKey: String {
            switch self {
            case .energy:
                return "Energy consumption"
            case .heart:
                return "Heart rate mean"
            case .respiratory:
                return "Respiratory rate"
            default:
                fatalError("this health sample shouldn't be written like metadata")
            }
        }
    }

    // MARK: - Private properties

    private let healthStore: HKHealthStore = HKHealthStore()
    private let dataTypesToRead: Set<HealthType>
    private let dataTypesToWrite: Set<HealthType>

    // MARK: - Public init

    public init(
        dataTypesToRead: Set<HealthType>,
        dataTypesToWrite: Set<HealthType>
    ) {
        self.dataTypesToRead = dataTypesToRead
        self.dataTypesToWrite = dataTypesToWrite
    }

}

// MARK: - Writing data

extension HealthCoreProvider {

    // MARK: - Public methods

    /// Writes data to `HealthStore`.
    public func writeData(
        data: [HKSample],
        writingErrorHandler: ErrorHandler,
        authorizationErrorHandler: ErrorHandler
    ) async {
        guard
            HKHealthStore.isHealthDataAvailable(),
            let sampleType = data.first?.sampleType,
            await isWritePermissionGranted(
                for: sampleType,
                authorizationErrorHandler: authorizationErrorHandler
            )
        else {
            return
        }
        await writeDataToHealthStore(
            data: data,
            writingErrorHandler: writingErrorHandler
        )
    }

    // MARK: - Private methods

    /// Checks if permission to save data in `HealthStore` was granted by user.
    private func isWritePermissionGranted(
        for objectType: HKObjectType,
        authorizationErrorHandler: ErrorHandler
    ) async -> Bool {
        let authorizationStatus = healthStore.authorizationStatus(for: objectType)
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
            await makeAuthorizationRequest(authorizationErrorHandler: authorizationErrorHandler)
            if healthStore.authorizationStatus(for: objectType) == .sharingAuthorized {
                Logger.logEvent("Succesfull HealthStore authorization.", type: .success)
                return true
            }
            Logger.logEvent(
                "Permission to write to HealthStore was denied by user.",
                type: .warning
            )
            authorizationErrorHandler()
            return false
        }
    }

    /// Saves data to `HealthStore`.
    private func writeDataToHealthStore(
        data: [HKSample],
        writingErrorHandler: ErrorHandler
    ) async {
        do {
            try await healthStore.save(data)
        } catch {
            Logger.logEvent("Unuccessfully wrote data to HealthStore.", type: .error)
            writingErrorHandler()
        }
        Logger.logEvent("Successfully wrote data to HealthStore.", type: .success)
    }

}

// MARK: - Reading data

extension HealthCoreProvider {
    public enum BundleAuthor {
        case sleepy
        case apple
        case everyone

        var predicate: NSPredicate? {
            switch self {
            case .sleepy:
                return HKQuery.predicateForObjects(from: HKSource.default())
            default:
                return nil
            }
        }

        var bundleDescription: [String] {
            switch self {
            case .sleepy:
                return ["com.benmustafa", "com.sinapsis"]
            case .apple:
                return ["com.apple"]
            case .everyone:
                return []
            }
        }
    }

    // MARK: - Public methods

    /// Reads data from `HealthStore`.
    @discardableResult
    public func readData(
        healthType: HealthType,
        dateInterval: DateInterval,
        ascending: Bool,
        limit: Int,
        author: BundleAuthor,
        queryOptions: HKQueryOptions,
        readingErrorHandler: ErrorHandler,
        authorizationErrorHandler: ErrorHandler
    ) async -> [HKSample]? {
        guard
            HKHealthStore.isHealthDataAvailable(),
            await isReadPermissionGranted(
                for: healthType,
                readingErrorHandler: readingErrorHandler,
                authorizationErrorHandler: authorizationErrorHandler
            )
        else {
            return nil
        }
        var data: [HKSample]?
        do {
            data = try await readDataFromHealthStore(
                healthType: healthType,
                dateInterval: dateInterval,
                ascending: ascending,
                limit: limit,
                author: author,
                queryOptions: queryOptions
            )
        } catch {
            return nil
        }
        return data
    }

    // MARK: - Private methods

    /// Checks if permission to read data from `HealthStore` was granted by user.
    private func isReadPermissionGranted(
        for healthType: HealthType,
        readingErrorHandler: ErrorHandler,
        authorizationErrorHandler: ErrorHandler
    ) async -> Bool {
        guard
            await !isAbleToReadData(
                healthType: healthType,
                readingErrorHandler: readingErrorHandler,
                shouldThrowError: false
            )
        else {
            return true
        }
        await makeAuthorizationRequest(authorizationErrorHandler: authorizationErrorHandler)
        guard
            await !isAbleToReadData(
                healthType: healthType,
                readingErrorHandler: readingErrorHandler,
                shouldThrowError: true
            )
        else {
            return true
        }
        return false
    }

    /// Tries to get the last data from `HealthStore` to determine if there is an ability to read data at all.
    private func isAbleToReadData(
        healthType: HealthType,
        readingErrorHandler: ErrorHandler,
        shouldThrowError: Bool
    ) async -> Bool {
        var lastData: [HKSample]?
        do {
            lastData = try await readLastDataFromHealthStore(for: healthType)
        } catch {
            Logger.logEvent(
                "Unsuccessfully finished reading data after making authorization request with error: \(error.localizedDescription)",
                type: .error
            )
            if shouldThrowError {
                readingErrorHandler()
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
            readingErrorHandler()
        }
        return false
    }

    /// Gets samples from `HealthStore` database using passed parameters.
    private func readDataFromHealthStore(
        healthType: HealthType,
        dateInterval: DateInterval,
        ascending: Bool,
        limit: Int,
        author: BundleAuthor,
        queryOptions: HKQueryOptions
    ) async throws -> [HKSample]? {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: healthType.hkValue,
                predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                    HKQuery.predicateForSamples(
                        withStart: dateInterval.start,
                        end: dateInterval.end,
                        options: queryOptions
                    ),
                    author.predicate
                ].compactMap { $0 }),
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: ascending)]
            ) { _, data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let samplesFiltered = data?.filter { sample in
                        (author.bundleDescription.contains(where: { sample.sourceRevision.source.bundleIdentifier.hasPrefix($0) })) &&
                        (sample as? HKCategorySample)?.value == ((healthType == .asleep)
                                                                 ? HKCategoryValueSleepAnalysis.asleep.rawValue
                                                                 : HKCategoryValueSleepAnalysis.inBed.rawValue)
                    }

                    continuation.resume(returning: samplesFiltered)
                }
            }
            healthStore.execute(query)
        }
    }

    /// Gets the last sample from `HealthStore`.
    private func readLastDataFromHealthStore(
        for healthType: HealthType
    ) async throws -> [HKSample]? {
        return try await readDataFromHealthStore(
            healthType: healthType,
            dateInterval: DateInterval(
                start: Date.distantPast,
                end: Date.distantFuture
            ),
            ascending: false,
            limit: 1,
            author: .everyone,
            queryOptions: []
        )
    }

}

// MARK: - Common

extension HealthCoreProvider {

    /// Makes `HealthStore` authorization request.
    private func makeAuthorizationRequest(
        authorizationErrorHandler: ErrorHandler
    ) async {
        do {
            try await healthStore.requestAuthorization(
                toShare: Set(self.dataTypesToWrite.map { $0.hkValue }),
                read: Set(self.dataTypesToRead.map { $0.hkValue })
            )
        } catch {
            Logger.logEvent("Unsuccessful HealthKit authorization request.", type: .error)
            authorizationErrorHandler()
        }
    }

}
