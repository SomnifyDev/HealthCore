import HealthKit
import CommonExtensions
import SwiftUI

public struct WorkoutData {

    public let id = UUID()
    public let workoutActivityType: HKWorkoutActivityType
    public let dateInterval: DateInterval
    public let duration: TimeInterval
    public let totalDistance: HKQuantity?
    public let totalEnergyBurned: HKQuantity?
    public let workoutEvents: [HKWorkoutEvent]?
    public let totalFlightsClimbed: HKQuantity?
    public let totalSwimmingStrokeCount: HKQuantity?

    public var isActivityOutdoors: Bool {
        self.totalDistance != nil
    }

    /// gets most importrant training value from bunch of non-empty ones
    public var mainValueDescription: String {
        let description: String

        if let totalDistance = self.totalDistance {
            let unit = HKUnit.meter()
            description = "\(Int(totalDistance.doubleValue(for: unit))) \(unit.unitString)"
        } else if let totalEnergyBurned = self.totalEnergyBurned {
            let unit = HKUnit.kilocalorie()
            description = "\(totalEnergyBurned.doubleValue(for: unit)) \(unit.unitString)"
        } else if let totalFlightsClimbed = self.totalFlightsClimbed {
            let unit = HKUnit.count()
            description = "\(totalFlightsClimbed.doubleValue(for: unit)) \(unit.unitString)"
        } else if let totalSwimmingStrokeCount = self.totalSwimmingStrokeCount {
            let unit = HKUnit.count()
            description = "\(totalSwimmingStrokeCount.doubleValue(for: unit)) \(unit.unitString)"
        } else {
            description = self.dateInterval.stringFromDateInterval(type: .time)
        }
        return description
    }
    
}
