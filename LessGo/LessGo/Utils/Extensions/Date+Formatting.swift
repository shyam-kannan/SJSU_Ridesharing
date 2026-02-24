import Foundation

extension Date {
    static var currentRoundedToMinute: Date {
        Calendar.autoupdatingCurrent.date(bySetting: .second, value: 0, of: Date()) ?? Date()
    }

    private static func displayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }

    // MARK: - Relative Time
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var relativeFull: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    // MARK: - Display Formats
    var tripDateString: String {
        let formatter = Self.displayFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: self)
    }

    var tripTimeString: String {
        let formatter = Self.displayFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var tripDateTimeString: String {
        let formatter = Self.displayFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: self)
    }

    var shortDateString: String {
        let formatter = Self.displayFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }

    var timeAgo: String {
        let seconds = Date().timeIntervalSince(self)
        switch seconds {
        case 0..<60:          return "Just now"
        case 60..<3600:       return "\(Int(seconds/60))m ago"
        case 3600..<86400:    return "\(Int(seconds/3600))h ago"
        case 86400..<604800:  return "\(Int(seconds/86400))d ago"
        default:              return shortDateString
        }
    }

    // MARK: - Countdown
    func minutesUntil() -> Int {
        Int(timeIntervalSinceNow / 60)
    }

    var countdownString: String {
        let mins = minutesUntil()
        if mins < 0 { return "Departed" }
        if mins == 0 { return "Leaving now" }
        if mins < 60 { return "Leaving in \(mins) min" }
        let hours = mins / 60
        let remaining = mins % 60
        if remaining == 0 { return "Leaving in \(hours)h" }
        return "Leaving in \(hours)h \(remaining)m"
    }

    // MARK: - API Format
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .autoupdatingCurrent
        return formatter.string(from: self)
    }
}
