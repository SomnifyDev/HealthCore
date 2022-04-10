import HealthKit
import CommonExtensions
import SwiftUI

public struct WorkoutData: Identifiable {

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
    
}

// MARK: - WorkoutData + String

extension WorkoutData {

    /// Gets most importrant training value from bunch of non-empty ones
    public var mainValueDescription: String {
        if let totalDistance = self.totalDistance {
            return totalDistanceDescription
        } else if let totalEnergyBurned = self.totalEnergyBurned {
            return totalEnergyBurnedDescription
        } else if let totalFlightsClimbed = self.totalFlightsClimbed {
            return totalFlightsClimbedDescription
        } else if let totalSwimmingStrokeCount = self.totalSwimmingStrokeCount {
            return totalSwimmingStrokeCountDescription
        } else {
            return dateIntervalDescription
        }
        return "-"
    }

    public var workoutActivityTypeDescription: String {
        return workoutActivityType.name
    }

    public var durationDescription: String {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: duration)
    }

    public var totalDistanceDescription: String {
        let unit = HKUnit.meter()
        return "\(Int(totalDistance.doubleValue(for: unit))) \(unit.unitString)"
    }

    public var totalEnergyBurnedDescription: String {
        let unit = HKUnit.kilocalorie()
        return "\(totalEnergyBurned.doubleValue(for: unit)) \(unit.unitString)"
    }

    public var totalFlightsClimbedDescription: String {
        let unit = HKUnit.count()
        description = "\(totalFlightsClimbed.doubleValue(for: unit)) \(unit.unitString)"
    }

    public var totalSwimmingStrokeCountDescription: String {
        let unit = HKUnit.count()
        return "\(totalSwimmingStrokeCount.doubleValue(for: unit)) \(unit.unitString)"
    }

    public var dateIntervalDescription: String {
        return dateInterval.stringFromDateInterval(type: .time)
    }

}
