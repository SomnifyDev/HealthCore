import Foundation
import HealthKit
import Logger

// MARK: - Public types

public typealias HealthCoreProviderAuthorizationErrorHandler = (HealthCoreProviderAuthorizationError) -> ()
public typealias HealthCoreProviderReadingDataErrorHandler = (HealthCoreProviderReadingDataError) -> ()
public typealias HealthCoreProviderWritingDataErrorHandler = (HealthCoreProviderWritingDataError) -> ()

public enum HealthCoreProviderAuthorizationError {
    case unsuccessfulAuthorization
}

public enum HealthCoreProviderWritingDataError {
    case unsuccessfulWriting
}

public enum HealthCoreProviderReadingDataError {
    case unsuccessfulReading
}

// MARK: - HealthCore

public final class HealthCoreProvider {

    // MARK: - Private properties

    private let healthStore: HKHealthStore = HKHealthStore()
    private let dataTypesToRead: Set<HKObjectType>
    private let dataTypesToWrite: Set<HKSampleType>

    // MARK: - Public init

    public init(
        dataTypesToRead: Set<HKSampleType>,
        dataTypesToWrite: Set<HKSampleType>
    ) {
        self.dataTypesToRead = dataTypesToRead
        self.dataTypesToWrite = dataTypesToWrite
    }

    // MARK: - Public methods

    /// Writes data to HealthStore.
    public func writeData(
        data: [HKSample],
        objectType: HKObjectType,
        writingErrorHandler: HealthCoreProviderWritingDataErrorHandler,
        authorizationErrorHandler: HealthCoreProviderAuthorizationErrorHandler
    ) async {
        if await isWritePermissionGranted(for: objectType, authorizationErrorHandler: authorizationErrorHandler) {
            await writeDataToHealthStore(
                data: data,
                writingErrorHandler: writingErrorHandler
            )
        } else {
            authorizationErrorHandler(.unsuccessfulAuthorization)
        }
    }

    /// Reads data from HealthStore.
    public func readData(
        sampleType: HKSampleType,
        dateInterval: DateInterval,
        ascending: Bool,
        limit: Int,
        queryOptions: HKQueryOptions?,
        authorizationErrorHandler: HealthCoreProviderAuthorizationErrorHandler
    ) async -> (HKSampleQuery?, [HKSample]?, Error?) {

        // TODO: - ErrorHandler

        guard await isReadPermissionGranted(
            for: sampleType,
            authorizationErrorHandler: authorizationErrorHandler
        ) else {
            return (nil, nil, nil)
        }

        var data: (HKSampleQuery?, [HKSample]?, Error?)
        do {
            data = try await readDataFromHealthStore(
                sampleType: sampleType,
                dateInterval: dateInterval,
                ascending: ascending,
                limit: limit,
                queryOptions: queryOptions
            )
        } catch {
            return (nil, nil, error)
        }

        return data

    }

    // MARK: - Private methods

    /// Checks if permission to save data in HealthStore was granted by user.
    private func isWritePermissionGranted(
        for objectType: HKObjectType,
        authorizationErrorHandler: HealthCoreProviderAuthorizationErrorHandler
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
            /* Checking authorization status after successful authorization request */
            if healthStore.authorizationStatus(for: objectType) == .sharingAuthorized {
                Logger.logEvent("Succesfull HealthStore authroization.", type: .success)
                return true
            }
            Logger.logEvent(
                "Permission to write to HealthStore was denied by user.",
                type: .warning
            )
            return false
        }
    }

    /// Saves data to HealthStore.
    private func writeDataToHealthStore(
        data: [HKSample],
        writingErrorHandler: HealthCoreProviderWritingDataErrorHandler
    ) async {
        do {
            try await healthStore.save(data)
        } catch {
            Logger.logEvent("Unuccessfully wrote data to HealthStore.", type: .error)
            writingErrorHandler(.unsuccessfulWriting)
        }
        Logger.logEvent("Successfully wrote data to HealthStore.", type: .success)
    }

    /// Checks if permission to read data from HealthStore was granted by user.
    private func isReadPermissionGranted(
        for sampleType: HKSampleType,
        authorizationErrorHandler: HealthCoreProviderAuthorizationErrorHandler
    ) async -> Bool {
        var lastData: (HKSampleQuery?, [HKSample]?, Error?)
        do { lastData = try await readLastData(for: sampleType) } catch {
            // - Error
        }
        guard (lastData.1 ?? []).isEmpty else {
            return true
        }
        await makeAuthorizationRequest(authorizationErrorHandler: authorizationErrorHandler)
        do { lastData = try await readLastData(for: sampleType) } catch {
            // - Error
        }
        guard (lastData.1 ?? []).isEmpty else {
            return true
        }
        return false
    }

    /// Gets samples from HealthStore's database using passed parameters.
    private func readDataFromHealthStore(
        sampleType: HKSampleType,
        dateInterval: DateInterval,
        ascending: Bool,
        limit: Int,
        queryOptions: HKQueryOptions?
    ) async throws -> (HKSampleQuery?, [HKSample]?, Error?) {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: HKQuery.predicateForSamples(
                    withStart: dateInterval.start,
                    end: dateInterval.end,
                    options: queryOptions ?? []
                ),
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: ascending)]
            ) { query, data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (query, data, error))
                }
            }
            healthStore.execute(query)
        }
    }

    /// Gets the last sample from HealthStore's database.
    private func readLastData(for sampleType: HKSampleType) async throws -> (HKSampleQuery?, [HKSample]?, Error?) {
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

    private func makeAuthorizationRequest(
        authorizationErrorHandler: HealthCoreProviderAuthorizationErrorHandler
    ) async {
        do {
            try await healthStore.requestAuthorization(
                toShare: dataTypesToWrite,
                read: dataTypesToRead
            )
        } catch {
            Logger.logEvent("Unsuccessful HealthKit authorization request.", type: .error)
            authorizationErrorHandler(.unsuccessfulAuthorization)
        }
    }

}
