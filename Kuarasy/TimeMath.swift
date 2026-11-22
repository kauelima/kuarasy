import Foundation

/// Pure time calculations. Everything takes explicit dates and zones so it can be tested.
enum TimeMath {
    static let slotMinutes = 15

    static func calendar(_ tz: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal
    }

    static func minuteOfDay(_ date: Date, in tz: TimeZone) -> Int {
        let c = calendar(tz).dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// True when `minute` falls in [start, end), wrapping past midnight when start > end.
    static func isInWindow(_ minute: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        if start < end { return minute >= start && minute < end }
        return minute >= start || minute < end
    }

    static func status(at date: Date, in tz: TimeZone, hours: WorkingHours) -> TimeStatus {
        let minute = minuteOfDay(date, in: tz)
        if isInWindow(minute, start: hours.sleepStart, end: hours.sleepEnd) { return .sleeping }
        let weekday = calendar(tz).component(.weekday, from: date)
        if hours.workdays.contains(weekday), isInWindow(minute, start: hours.start, end: hours.end) {
            return .working
        }
        return .offHours
    }

    static func solarPhase(at date: Date, in tz: TimeZone) -> SolarPhase {
        switch minuteOfDay(date, in: tz) / 60 {
        case 5..<8: .sunrise
        case 8..<17: .day
        case 17..<20: .sunset
        default: .night
        }
    }

    // MARK: Offsets

    /// Seconds `tz` is ahead of `home` at `date` (negative when behind).
    static func offsetSeconds(_ tz: TimeZone, relativeTo home: TimeZone, at date: Date) -> Int {
        tz.secondsFromGMT(for: date) - home.secondsFromGMT(for: date)
    }

    /// "+4h", "−3h", "+5:30", or "Same time".
    static func relativeOffsetLabel(seconds: Int) -> String {
        if seconds == 0 { return "Same time" }
        let hours = signedHours(seconds)
        return hours.contains(":") ? hours : hours + "h"
    }

    /// "UTC−3", "UTC+5:30", "UTC".
    static func utcOffsetLabel(_ tz: TimeZone, at date: Date) -> String {
        let seconds = tz.secondsFromGMT(for: date)
        return seconds == 0 ? "UTC" : "UTC" + signedHours(seconds)
    }

    private static func signedHours(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "\u{2212}" : "+"
        let total = abs(seconds) / 60
        let h = total / 60, m = total % 60
        return m == 0 ? "\(sign)\(h)" : "\(sign)\(h):" + String(format: "%02d", m)
    }

    /// Whether the calendar day in `tz` is before, equal to, or after the day in `home`.
    static func dayRelation(at date: Date, in tz: TimeZone, home: TimeZone) -> DayRelation {
        let diff = dayNumber(date, tz) - dayNumber(date, home)
        return DayRelation(rawValue: max(-1, min(1, diff))) ?? .today
    }

    private static func dayNumber(_ date: Date, _ tz: TimeZone) -> Int {
        let c = calendar(tz).dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let d = utc.date(from: c) ?? date
        return Int((d.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    // MARK: Day timeline

    /// The home-zone day that contains `date`, as [start, end). Handles 23h/25h DST days.
    static func day(containing date: Date, in home: TimeZone) -> DateInterval {
        let cal = calendar(home)
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    struct Slot: Equatable, Sendable {
        var start: Date
        var status: TimeStatus
    }

    /// Fifteen-minute slots across `day`. Each slot takes the worst status among `zones`:
    /// working only if everyone is working, sleeping if anyone is asleep.
    static func overlapSlots(day: DateInterval, zones: [TimeZone], hours: WorkingHours) -> [Slot] {
        let step = TimeInterval(slotMinutes * 60)
        let count = Int((day.duration / step).rounded())
        return (0..<count).map { i in
            let start = day.start.addingTimeInterval(Double(i) * step)
            let worst = zones.map { status(at: start, in: $0, hours: hours) }.max() ?? .working
            return Slot(start: start, status: worst)
        }
    }

    /// Consecutive slots with the same status merged, as fractions of the day for drawing.
    struct Run: Equatable, Sendable {
        var from: Double
        var to: Double
        var status: TimeStatus
    }

    static func runs(_ slots: [Slot], day: DateInterval) -> [Run] {
        var result: [Run] = []
        for (i, slot) in slots.enumerated() {
            let from = slot.start.timeIntervalSince(day.start) / day.duration
            let to = i + 1 < slots.count
                ? slots[i + 1].start.timeIntervalSince(day.start) / day.duration
                : 1
            if let last = result.last, last.status == slot.status {
                result[result.count - 1].to = to
            } else {
                result.append(Run(from: from, to: to, status: slot.status))
            }
        }
        return result
    }

    /// Rounds a date to the nearest slot boundary, measured from the day start.
    static func snap(_ date: Date, in day: DateInterval) -> Date {
        let step = TimeInterval(slotMinutes * 60)
        let offset = (date.timeIntervalSince(day.start) / step).rounded() * step
        return day.start.addingTimeInterval(min(max(0, offset), day.duration - step))
    }
}
