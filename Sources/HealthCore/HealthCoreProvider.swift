import Foundation
import HealthKit
import Logger

// MARK: - Public types

public typealias ErrorHandler = () -> ()

// MARK: - HealthCoreProvider

public final class HealthCoreProvider {

    // MARK: - Private properties

    private let healthStore: HKHealthStore = HKHealthStore()
    private let dataTypesToRead: Set<HKSampleType>
    private let dataTypesToWrite: Set<HKSampleType>

    // MARK: - Public init

    public init(
        dataTypesToRead: Set<HKSampleType>,
        dataTypesToWrite: Set<HKSampleType>
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

    // MARK: - Public methods

    /// Reads data from `HealthStore`.
    @discardableResult
    public func readData(
        sampleType: HKSampleType,
        dateInterval: DateInterval,
        ascending: Bool,
        limit: Int,
        queryOptions: HKQueryOptions,
        readingErrorHandler: ErrorHandler,
        authorizationErrorHandler: ErrorHandler
    ) async -> [HKSample]? {
        guard
            HKHealthStore.isHealthDataAvailable(),
            await isReadPermissionGranted(
                for: sampleType,
                readingErrorHandler: readingErrorHandler,
                authorizationErrorHandler: authorizationErrorHandler
            )
        else {
            return nil
        }
        var data: [HKSample]?
        do {
            data = try await readDataFromHealthStore(
                sampleType: sampleType,
                dateInterval: dateInterval,
                ascending: ascending,
                limit: limit,
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
        for sampleType: HKSampleType,
        readingErrorHandler: ErrorHandler,
        authorizationErrorHandler: ErrorHandler
    ) async -> Bool {
        guard
            await !isAbleToReadData(
                sampleType: sampleType,
                readingErrorHandler: readingErrorHandler,
                shouldThrowError: false
            )
        else {
            return true
        }
        await makeAuthorizationRequest(authorizationErrorHandler: authorizationErrorHandler)
        guard
            await !isAbleToReadData(
                sampleType: sampleType,
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
        sampleType: HKSampleType,
        readingErrorHandler: ErrorHandler,
        shouldThrowError: Bool
    ) async -> Bool {
        var lastData: [HKSample]?
        do {
            lastData = try await readLastDataFromHealthStore(for: sampleType)
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
        sampleType: HKSampleType,
        dateInterval: DateInterval,
        ascending: Bool,
        limit: Int,
        queryOptions: HKQueryOptions
    ) async throws -> [HKSample]? {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
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
                    continuation.resume(returning: data)
                }
            }
            healthStore.execute(query)
        }
    }

    /// Gets the last sample from `HealthStore`.
    private func readLastDataFromHealthStore(
        for sampleType: HKSampleType
    ) async throws -> [HKSample]? {
        return try await readDataFromHealthStore(
            sampleType: sampleType,
            dateInterval: DateInterval(
                start: Date.distantPast,
                end: Date.distantFuture
            ),
            ascending: false,
            limit: 1,
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
                toShare: dataTypesToWrite,
                read: dataTypesToRead
            )
        } catch {
            Logger.logEvent("Unsuccessful HealthKit authorization request.", type: .error)
            authorizationErrorHandler()
        }
    }

}
