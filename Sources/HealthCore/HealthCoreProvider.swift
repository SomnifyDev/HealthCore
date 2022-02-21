import Foundation
import HealthKit

// MARK: - Public types

public typealias HealthCoreProviderErrorHandler = (HealthCoreProviderError) -> ()

public enum HealthCoreProviderError: Error {
    case unsuccessfulAuthorizationError
    case unsuccessfulSavingDataToHealthStore
    case unsuccessfulWritingDataToHealthStore
}

// MARK: - HealthCore

public final class HealthCoreProvider {

    // MARK: - Private properties

    private let healthStore: HKHealthStore = HKHealthStore()
    private let dataTypesToRead: Set<HKObjectType>
    private let dataTypesToWrite: Set<HKSampleType>
    private let healthCoreProviderErrorHandler: HealthCoreProviderErrorHandler

    // MARK: - Public init

    public init(
        dataTypesToRead: Set<HKObjectType>,
        dataTypesToWrite: Set<HKSampleType>,
        healthCoreProviderErrorHandler: @escaping HealthCoreProviderErrorHandler
    ) {
        self.dataTypesToRead = dataTypesToRead
        self.dataTypesToWrite = dataTypesToWrite
        self.healthCoreProviderErrorHandler = healthCoreProviderErrorHandler
    }

    // MARK: - Public methods

    /// Writes data to HealthStore.
    public func writeDataToHealthStore(
        data: [HKSample],
        objectType: HKObjectType
    ) async {
        if await isSavePermissionGranted(for: objectType) {
            await saveDataToHealthStore(data: data)
        } else {
            healthCoreProviderErrorHandler(.unsuccessfulAuthorizationError)
        }
    }

    // MARK: - Private methods

    /// Checks if permission to save data in HealthStore was granted by user.
    private func isSavePermissionGranted(for objectType: HKObjectType) async -> Bool {
        switch healthStore.authorizationStatus(for: objectType) {
        case .sharingAuthorized:
            return true
        default:
            do {
                try await healthStore.requestAuthorization(
                    toShare: dataTypesToWrite,
                    read: dataTypesToRead
                )
            } catch {
                healthCoreProviderErrorHandler(.unsuccessfulAuthorizationError)
            }
            return false
        }
    }

    /// Checks if permission to read data from HealthStore was granted by user.
    private func isReadPermissionGranted(for sampleType: HKSampleType) async throws -> Bool {
        let lastData = try await readLastData(for: sampleType)
        guard (lastData.1 ?? []).isEmpty else {
            return true
        }
        try await healthStore.requestAuthorization(
            toShare: dataTypesToWrite,
            read: dataTypesToRead
        )
        return false
    }

    /// Gets the last sample in HealthStore database.
    private func readLastData(for sampleType: HKSampleType) async throws -> (HKSampleQuery?, [HKSample]?, Error?) {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: HKQuery.predicateForSamples(
                    withStart: Date.distantPast,
                    end: Date.distantFuture,
                    options: []
                ),
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
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


    /// Saves data to HealthStore.
    private func saveDataToHealthStore(data: [HKSample]) async {
        do {
            try await healthStore.save(data)
        } catch {
            healthCoreProviderErrorHandler(.unsuccessfulSavingDataToHealthStore)
        }
    }

}
