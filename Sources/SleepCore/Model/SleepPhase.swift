import Foundation

// MARK: - Public types

public typealias SampleData = (date: Date, value: Double)

// MARK: - SleepPhase

public struct SleepPhase {
    
    // TODO: - Implement SleepPhases as it should be
    public let heartData: [SampleData]
    public let energyData: [SampleData]
    public let respiratoryData: [SampleData]
    
}
