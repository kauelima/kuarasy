import Foundation

/// A saved clock: one time zone, optionally with a custom label.
struct Location: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var timeZoneID: String
    var alias: String
    var cityName: String
    /// Whether this zone shapes the "good time" bar. Reference zones (false) are listed
    /// below the bar in a compact row and only follow the scrubbed time.
    var countsTowardBar: Bool

    init(id: UUID = UUID(), timeZoneID: String, alias: String = "", cityName: String? = nil,
         countsTowardBar: Bool = true) {
        self.id = id
        self.timeZoneID = timeZoneID
        self.alias = alias
        self.cityName = cityName ?? TimeZoneCatalog.cityName(for: timeZoneID)
        self.countsTowardBar = countsTowardBar
    }

    // Locations saved before `countsTowardBar` existed decode as counting.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        timeZoneID = try c.decode(String.self, forKey: .timeZoneID)
        alias = try c.decode(String.self, forKey: .alias)
        cityName = try c.decode(String.self, forKey: .cityName)
        countsTowardBar = try c.decodeIfPresent(Bool.self, forKey: .countsTowardBar) ?? true
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// Alias when set, otherwise the city.
    var title: String {
        let trimmed = alias.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? cityName : trimmed
    }

    /// The city, only when an alias is shown as the title.
    var subtitle: String? {
        alias.trimmingCharacters(in: .whitespaces).isEmpty ? nil : cityName
    }
}

/// Global working and sleeping windows, in minutes from local midnight.
/// Windows may wrap past midnight (e.g. sleep 22:00 to 07:00).
struct WorkingHours: Codable, Hashable, Sendable {
    var start: Int = 9 * 60
    var end: Int = 18 * 60
    var sleepStart: Int = 22 * 60
    var sleepEnd: Int = 7 * 60
    /// `Calendar` weekdays: 1 = Sunday ... 7 = Saturday.
    var workdays: Set<Int> = [2, 3, 4, 5, 6]
}

enum MenuBarMode: String, Codable, CaseIterable, Sendable {
    case icon, time, iconAndTime

    var label: String {
        switch self {
        case .icon: "Icon"
        case .time: "Time"
        case .iconAndTime: "Both"
        }
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var homeTimeZoneID: String = TimeZone.current.identifier
    /// Location shown in the menu bar. `nil` means the home zone.
    var pinnedLocationID: UUID?
    var use24Hour: Bool = true
    var menuBarMode: MenuBarMode = .iconAndTime
    var hours = WorkingHours()
}

/// How good a moment is for someone, matching the converter colours:
/// green (working), yellow (awake, not working), red (asleep).
enum TimeStatus: Int, Comparable, Sendable, CaseIterable {
    case working = 0, offHours = 1, sleeping = 2

    static func < (a: TimeStatus, b: TimeStatus) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .working: "Working"
        case .offHours: "Off hours"
        case .sleeping: "Asleep"
        }
    }

    var symbol: String {
        switch self {
        case .working: "briefcase.fill"
        case .offHours: "cup.and.saucer.fill"
        case .sleeping: "bed.double.fill"
        }
    }
}

enum SolarPhase: Sendable {
    case sunrise, day, sunset, night

    var symbol: String {
        switch self {
        case .sunrise: "sunrise.fill"
        case .day: "sun.max.fill"
        case .sunset: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}

enum DayRelation: Int, Sendable {
    case yesterday = -1, today = 0, tomorrow = 1

    var label: String {
        switch self {
        case .yesterday: "Yesterday"
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        }
    }
}
