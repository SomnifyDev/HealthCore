import Foundation
import HealthKit

// MARK: - Sleep

public struct Sleep {

    // MARK: - Public properties

    public var samples: [MicroSleep]

    public var phases: [SleepPhase] {
        return samples.compactMap { $0.phases }.flatMap { $0 }
    }
    public var sleepInterval: DateInterval? {
        return dateInterval(between: samples.first?.sleepInterval, and: samples.last?.sleepInterval)
    }
    public var inbedInterval: DateInterval? {
        return dateInterval(between: samples.first?.inBedInterval, and: samples.last?.inBedInterval)
    }
    public var heartData: [SampleData] {
        return self.samples.flatMap { $0.heartData }
    }
    public var energyData: [SampleData] {
        return self.samples.flatMap { $0.energyData }
    }
    public var respiratoryData: [SampleData] {
        return self.samples.flatMap { $0.respiratoryData }
    }

    // MARK: - Init

    public init(samples: [MicroSleep]) {
        self.samples = samples
    }

    // MARK: - Private methods

    private func dateInterval(
        between leadingInterval: DateInterval?,
        and trailingInterval: DateInterval?
    ) -> DateInterval? {
        guard
            let startDate = leadingInterval?.start,
            let endDate = trailingInterval?.end
        else {
            return nil
        }
        return DateInterval(start: startDate, end: endDate)
    }

}

// MARK: - MicroSleep

public struct MicroSleep {

    // MARK: - Public properties

    public let sleepInterval: DateInterval
    public let inBedInterval: DateInterval
    public let phases: [SleepPhase]?

    public var heartData: [SampleData] {
        return self.phases?.flatMap { $0.heartData } ?? []
    }
    public var energyData: [SampleData] {
        return self.phases?.flatMap { $0.energyData } ?? []
    }
    public var respiratoryData: [SampleData] {
        return self.phases?.flatMap { $0.respiratoryData } ?? []
    }

    // MARK: - Init

    public init(
        sleepInterval: DateInterval,
        inBedInterval: DateInterval,
        phases: [SleepPhase]?
    ) {
        self.sleepInterval = sleepInterval
        self.inBedInterval = inBedInterval
        self.phases = phases
    }

}
