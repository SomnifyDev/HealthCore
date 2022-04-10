import HealthKit
import CommonExtensions
import SwiftUI
import CoreLocation
import HeartCore
import HealthCore

public struct WorkoutRouteData {
    public let dateInterval: DateInterval
    public let locations: [CLLocation]
}

public struct WorkoutData: Identifiable {

    public let id = UUID()
    public let workoutActivityType: HKWorkoutActivityType
    public let dateInterval: DateInterval
    public let duration: TimeInterval
    public let totalDistance: HKQuantity?
    public let routeData: [WorkoutRouteData]?
    public let heartInterpolatedData: [QuantityData]?
    public let totalEnergyBurned: HKQuantity?
    public let workoutEvents: [HKWorkoutEvent]?
    public let totalFlightsClimbed: HKQuantity?
    public let totalSwimmingStrokeCount: HKQuantity?
    public let rawSample: HKWorkout

    public var isActivityOutdoors: Bool {
        self.totalDistance != nil
    }
    
}

// MARK: - WorkoutData + String

extension WorkoutData {

    /// Gets most importrant training value from bunch of non-empty ones
    public var mainValueDescription: String {
        if self.totalDistance != nil {
            return totalDistanceDescription
        } else if self.totalEnergyBurned != nil {
            return totalEnergyBurnedDescription
        } else if self.totalFlightsClimbed != nil {
            return totalFlightsClimbedDescription
        } else if self.totalSwimmingStrokeCount != nil {
            return totalSwimmingStrokeCountDescription
        } else {
            return dateIntervalDescription
        }
    }

    public var workoutActivityTypeDescription: String {
        return workoutActivityType.name
    }

    public var durationDescription: String {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: duration) ?? "-"
    }

    public var totalDistanceDescription: String {
        let unit = HKUnit.meter()
        if let totalDistance = totalDistance?.doubleValue(for: unit) {
            return "\(Int(totalDistance)) \(unit.unitString)"
        }
        return "-"
    }

    public var totalEnergyBurnedDescription: String {
        let unit = HKUnit.kilocalorie()
        if let totalEnergyBurned = totalEnergyBurned?.doubleValue(for: unit) {
            return "\(totalEnergyBurned) \(unit.unitString)"
        }
        return "-"
    }

    public var totalFlightsClimbedDescription: String {
        let unit = HKUnit.count()
        if let totalFlightsClimbed = totalFlightsClimbed?.doubleValue(for: unit) {
            return "\(totalFlightsClimbed) \(unit.unitString)"
        }
        return "-"
    }

    public var totalSwimmingStrokeCountDescription: String {
        let unit = HKUnit.count()
        if let totalSwimmingStrokeCount = totalSwimmingStrokeCount?.doubleValue(for: unit) {
            return "\(totalSwimmingStrokeCount) \(unit.unitString)"
        }
        return "-"
    }

    public var dateIntervalDescription: String {
        return dateInterval.stringFromDateInterval(type: .time)
    }

}
