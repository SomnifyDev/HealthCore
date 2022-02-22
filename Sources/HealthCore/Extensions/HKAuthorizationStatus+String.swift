import Foundation
import HealthKit

extension HKAuthorizationStatus {

    var description: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .sharingDenied:
            return "sharingDenied"
        case .sharingAuthorized:
            return "sharingAuthorized"
        @unknown default:
            return "unknownStatus"
        }
    }

}
