import Foundation

// MARK: - Public types

public typealias SampleData = (date: Date, value: Double)

public enum Condition {
    case awake
    case light
    case deep
}

// MARK: - SleepPhase


public struct SleepPhase {
    
    public let dateInterval: DateInterval
    public let condition: Condition
    public let heartData: [SampleData]
    public let energyData: [SampleData]
    public let respiratoryData: [SampleData]
    
}
