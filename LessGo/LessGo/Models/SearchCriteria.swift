import Foundation
import CoreLocation

// MARK: - Search Criteria Model

struct SearchCriteria {
    let direction: TripDirection
    let location: String
    let coordinate: CLLocationCoordinate2D
    let departureTime: Date

    enum TripDirection: String {
        case toSJSU = "to_sjsu"
        case fromSJSU = "from_sjsu"
    }
}
