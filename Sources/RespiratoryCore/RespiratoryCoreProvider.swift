//
//  RespiratoryCoreProvider.swift
//  
//
//  Created by Никита Казанцев on 10.04.2022.
//

import Foundation
import HealthCore
import HealthKit
import Logger

// MARK: - RespiratoryCoreProvider

public final class RespiratoryCoreProvider: ObservableObject {

    // MARK: - Private properties

    private let healthCoreProvider: HealthCoreProvider
    private let healthStore: HKHealthStore = HKHealthStore()

    // MARK: - Init

    public init(healthCoreProvider: HealthCoreProvider) {
        self.healthCoreProvider = healthCoreProvider
    }

    // MARK: - Public methods

    /// Returns simple breath data of the user with it's (measurment) `value` and `recordingDate`
    public func getRespiratoryData(
        dateInterval: DateInterval,
        ascending: Bool = true,
        limit: Int = HKObjectQueryNoLimit,
        author: HealthCoreProvider.BundleAuthor = .all,
        queryOptions: HKQueryOptions = [],
        arrayModification: ArrayModifyType = .none
    ) async throws -> [QuantityData]? {
        guard
            let respiratoryData = try await self.healthCoreProvider.readData(
                sampleType: .quantityType(forIdentifier: .respiratoryRate),
                dateInterval: dateInterval,
                ascending: ascending,
                limit: limit,
                author: author,
                queryOptions: queryOptions
            ) as? [HKQuantitySample],
            !respiratoryData.isEmpty
        else {
            return nil
        }


        switch arrayModification {
        case .interpolate:
            return self.healthCoreProvider.getQuantitiveDataInterpolated(from: self.healthCoreProvider.makeQuantityData(from: respiratoryData, unit: .countMin()))
        case .shorten:
            return self.healthCoreProvider.getQuantitiveDataShortened(from: self.healthCoreProvider.makeQuantityData(from: respiratoryData, unit: .countMin()))
        case .none:
            return self.healthCoreProvider.makeQuantityData(from: respiratoryData, unit: .countMin())
        }
    }
}
