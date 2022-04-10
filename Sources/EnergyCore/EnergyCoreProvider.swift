//
//  EnergyCoreProvider.swift
//  
//
//  Created by Никита Казанцев on 08.04.2022.
//

import Foundation
import HealthCore
import HealthKit
import Logger

// MARK: - EnergyCoreProvider

public final class EnergyCoreProvider: ObservableObject {

    // MARK: - Private properties

    private let healthCoreProvider: HealthCoreProvider
    private let healthStore: HKHealthStore = HKHealthStore()

    // MARK: - Init

    public init(healthCoreProvider: HealthCoreProvider) {
        self.healthCoreProvider = healthCoreProvider
    }

    // MARK: - Public methods

    /// Returns simple energy burn data of the user with it's (measurment) `value` and `recordingDate`
    public func getActiveEnergyBurnData(
        dateInterval: DateInterval,
        ascending: Bool = true,
        limit: Int = HKObjectQueryNoLimit,
        author: HealthCoreProvider.BundleAuthor = .all,
        queryOptions: HKQueryOptions = [],
        arrayModification: ArrayModifyType = .none
    ) async throws -> [QuantityData]? {
        guard
            let energyData = try await self.healthCoreProvider.readData(
                sampleType: .quantityType(forIdentifier: .activeEnergyBurned),
                dateInterval: dateInterval,
                ascending: ascending,
                limit: limit,
                author: author,
                queryOptions: queryOptions
            ) as? [HKQuantitySample],
            !energyData.isEmpty
        else {
            return nil
        }


        switch arrayModification {
        case .interpolate:
            return self.healthCoreProvider.getQuantitiveDataInterpolated(from: self.healthCoreProvider.makeQuantityData(from: energyData, unit: .kilocalorie()))
        case .shorten:
            return self.healthCoreProvider.getQuantitiveDataShortened(from: self.healthCoreProvider.makeQuantityData(from: energyData, unit: .kilocalorie()))
        case .none:
            return self.healthCoreProvider.makeQuantityData(from: energyData, unit: .kilocalorie())
        }
    }
}
