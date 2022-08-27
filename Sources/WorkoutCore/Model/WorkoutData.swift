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

    // MARK: Metadata, Workout Type

    /// indicates whether the workout was performed with a coach or personal trainer
    public var isCoached: Bool? {
        rawSample.metadata?[HKMetadataKeyCoachedWorkout] as? Bool
    }

    // MARK: Metadata, Speed

    /// average speed in meters per second
    public var averageSpeed: Double? {
        (rawSample.metadata?[HKMetadataKeyAverageSpeed] as? HKQuantity)?
            .doubleValue(for: HKUnit.meter().unitDivided(by: HKUnit.second()))
    }

    /// maximum speed in meters per second
    public var maximumSpeed: Double? {
        (rawSample.metadata?[HKMetadataKeyMaximumSpeed] as? HKQuantity)?
            .doubleValue(for: HKUnit.meter().unitDivided(by: HKUnit.second()))
    }

    // MARK: Metadata, Intensity

    /// average Metabolic Equivalent of Task (METs) during a workout. kcal/(kg*hr)
    public var averageMETs: Double? {
        (rawSample.metadata?[HKMetadataKeyAverageMETs] as? HKQuantity)?
            .doubleValue(for: HKUnit(from: "kcal/(kg*hr)"))
    }

    // MARK: Metadata, Swimming

    /// The possible locations for swimming
    public var swimmingLocationType: HKWorkoutSwimmingLocationType? {
        if let locationTypeNum = rawSample.metadata?[HKMetadataKeySwimmingLocationType] as? Int {
            return HKWorkoutSwimmingLocationType.init(rawValue: locationTypeNum)
        } else {
            return nil
        }
    }

    /// A key that indicates the predominant stroke style for a lap of swimming
    public var swimmingStrokeStyle: HKSwimmingStrokeStyle? {
        if let strokeStyleNum = rawSample.metadata?[HKMetadataKeySwimmingStrokeStyle] as? Int {
            return HKSwimmingStrokeStyle.init(rawValue: strokeStyleNum)
        } else {
            return nil
        }
    }

    // MARK: Metadata, Skiing and Snowboarding

    /// indicates the percent slope of a ski run. where 100% indicates a 45 degree slope
    public var alpineSlopeGrade: Double? {
        (rawSample.metadata?[HKMetadataKeyAlpineSlopeGrade] as? HKQuantity)?
            .doubleValue(for: HKUnit.percent())
    }

    /// indicates the cumulative elevation ascended during a workout, meters.
    public var elevationAscended: Double? {
        (rawSample.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?
            .doubleValue(for: HKUnit.meter())
    }

    /// indicates the cumulative elevation descended during a workout, meters.
    public var elevationdescended: Double? {
        (rawSample.metadata?[HKMetadataKeyElevationDescended] as? HKQuantity)?
            .doubleValue(for: HKUnit.meter())
    }

    // MARK: Metadata: GymKit Fitness Equipment

    /// The workout duration displayed by a connected GymKit fitness machine. Minutes
    public var fitnessMachineDuration: Double? {
        (rawSample.metadata?[HKMetadataKeyFitnessMachineDuration] as? HKQuantity)?
            .doubleValue(for: HKUnit.minute())
    }

    /// The workout distance displayed by a connected GymKit cross-trainer machine. meters
    public var keyCrossTrainerDistance: Double? {
        (rawSample.metadata?[HKMetadataKeyCrossTrainerDistance] as? HKQuantity)?
            .doubleValue(for: HKUnit.meter())
    }

    /// The workout distance displayed by a connected GymKit exercise bike, meters.
    public var indoorBikeDistance: Double? {
        (rawSample.metadata?[HKMetadataKeyIndoorBikeDistance] as? HKQuantity)?
            .doubleValue(for: HKUnit.meter())
    }

}

// MARK: - WorkoutData + String

extension WorkoutData {

    /// Gets most importrant training value from bunch of non-empty ones
    public var mainValueDescription: String {
        if let totalDistanceDescription = totalDistanceDescription {
            return totalDistanceDescription
        } else if let totalEnergyBurnedDescription = totalEnergyBurnedDescription {
            return totalEnergyBurnedDescription
        } else if let totalFlightsClimbedDescription = totalFlightsClimbedDescription {
            return totalFlightsClimbedDescription
        } else if let totalSwimmingStrokeCountDescription = totalSwimmingStrokeCountDescription {
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

    public var totalDistanceDescription: String? {
        let unit = HKUnit.meter()
        if let totalDistance = totalDistance?.doubleValue(for: unit) {
            return "\(String(format:"%.2f", totalDistance)) \(unit.unitString)"
        }
        return nil
    }

    public var totalEnergyBurnedDescription: String? {
        let unit = HKUnit.kilocalorie()
        if let totalEnergyBurned = totalEnergyBurned?.doubleValue(for: unit) {
            return "\(String(format:"%.2f", totalEnergyBurned)) \(unit.unitString)"
        }
        return nil
    }

    public var totalFlightsClimbedDescription: String? {
        let unit = HKUnit.count()
        if let totalFlightsClimbed = totalFlightsClimbed?.doubleValue(for: unit) {
            return "\(totalFlightsClimbed) \(unit.unitString)"
        }
        return nil
    }

    public var totalSwimmingStrokeCountDescription: String? {
        let unit = HKUnit.count()
        if let totalSwimmingStrokeCount = totalSwimmingStrokeCount?.doubleValue(for: unit) {
            return "\(totalSwimmingStrokeCount) \(unit.unitString)"
        }
        return nil
    }

    public var dateIntervalDescription: String {
        return dateInterval.stringFromDateInterval(type: .time)
    }

    // MARK: Metadata

    /// indicates whether the workout was performed with a coach or personal trainer
    public var isCoachedDescription: String? {
        if let isCoached = self.isCoached {
            return "Yes"
        }
        return nil
    }

    // MARK: Metadata, Speed

    /// average speed in meters per second
    public var averageSpeedDescription: String? {
        if let averageSpeed = self.averageSpeed {
            return String(format:"%.2f", averageSpeed)
        }
        return nil
    }

    /// maximum speed in meters per second
    public var maximumSpeedDescription: String? {
        if let maximumSpeed = self.maximumSpeed {
            return String(format:"%.2f", maximumSpeed)
        }
        return nil
    }

    // MARK: Metadata, Intensity

    /// average Metabolic Equivalent of Task (METs) during a workout. kcal/(kg*hr)
    public var averageMETsDescription: String? {
        if let averageMETs = self.averageMETs {
            return String(String(format:"%.2f", averageMETs))
        }
        return nil
    }

    // MARK: Metadata, Swimming

    /// The possible locations for swimming
    public var swimmingLocationTypeDescription: String? {
        if let swimmingLocationType = self.swimmingLocationType {
            switch swimmingLocationType {
            case .unknown:
                return nil
            case .pool:
                return "pool"
            case .openWater:
                return "open water"
            }
        }
        return nil
    }

    /// A key that indicates the predominant stroke style for a lap of swimming
    public var swimmingStrokeStyleDescription: String? {
        if let swimmingStrokeStyle = self.swimmingStrokeStyle {
            switch swimmingStrokeStyle {
            case .unknown:
                return "freestyle"
            case .mixed:
                return "mixed"
            case .freestyle:
                return "freestyle"
            case .backstroke:
                return "backstroke"
            case .breaststroke:
                return "breaststroke"
            case .butterfly:
                return "butterfly"
            }
        }
        return nil
    }

    // MARK: Metadata, Skiing and Snowboarding

    /// indicates the percent slope of a ski run. where 100% indicates a 45 degree slope
    public var alpineSlopeGradeDescription: String? {
        if let alpineSlopeGrade = self.alpineSlopeGrade {
            return String(Int(alpineSlopeGrade * 100) / 100)
        }
        return nil
    }

    /// indicates the cumulative elevation ascended during a workout, meters.
    public var elevationAscendedDescription: String? {
        if let elevationAscended = self.elevationAscended {
            return String(String(format:"%.2f", elevationAscended))
        }
        return nil
    }

    /// indicates the cumulative elevation descended during a workout, meters.
    public var elevationdescendedDescription: String? {
        if let elevationdescended = self.elevationdescended {
            return String(String(format:"%.2f", elevationdescended))
        }
        return nil
    }

    // MARK: Metadata: GymKit Fitness Equipment

    /// The workout duration displayed by a connected GymKit fitness machine. Minutes
    public var fitnessMachineDurationDescription: String? {
        if let fitnessMachineDuration = self.fitnessMachineDuration {
            return String(Int(fitnessMachineDuration))
        }
        return nil
    }

    /// The workout distance displayed by a connected GymKit cross-trainer machine. meters
    public var keyCrossTrainerDistanceDescription: String? {
        if let keyCrossTrainerDistance = self.keyCrossTrainerDistance {
            return String(Int(keyCrossTrainerDistance))
        }
        return nil
    }

    /// The workout distance displayed by a connected GymKit exercise bike, meters.
    public var indoorBikeDistanceDescription: String? {
        if let indoorBikeDistance = self.indoorBikeDistance {
            return String(Int(indoorBikeDistance))
        }
        return nil
    }

}
