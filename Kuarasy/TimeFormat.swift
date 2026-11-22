import Foundation

/// Display formatting for clock times.
enum TimeFormat {
    /// "14:05" or "2:05" (the AM/PM marker comes from `period`).
    static func time(_ date: Date, in tz: TimeZone, use24Hour: Bool) -> String {
        formatter(use24Hour ? "HH:mm" : "h:mm", tz).string(from: date)
    }

    /// "AM"/"PM" in 12h mode, nil in 24h.
    static func period(_ date: Date, in tz: TimeZone, use24Hour: Bool) -> String? {
        use24Hour ? nil : formatter("a", tz).string(from: date)
    }

    /// Compact time for the menu bar: "14:05" or "2:05 PM".
    static func compact(_ date: Date, in tz: TimeZone, use24Hour: Bool) -> String {
        formatter(use24Hour ? "HH:mm" : "h:mm a", tz).string(from: date)
    }

    /// "Wed 18 Nov".
    static func shortDay(_ date: Date, in tz: TimeZone) -> String {
        formatter("EEE d MMM", tz).string(from: date)
    }

    /// Hour tick label for the timeline: "06" or "6a".
    static func hourTick(_ hour: Int, use24Hour: Bool) -> String {
        if use24Hour { return String(format: "%02d", hour % 24) }
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour % 24 < 12 ? "a" : "p")"
    }

    /// "in 2h 15m", "3h ago", "now".
    static func relative(_ date: Date, to now: Date) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded())
        if abs(minutes) < 1 { return "now" }
        let h = abs(minutes) / 60, m = abs(minutes) % 60
        let span = h == 0 ? "\(m)m" : (m == 0 ? "\(h)h" : "\(h)h \(m)m")
        return minutes > 0 ? "in \(span)" : "\(span) ago"
    }

    private static func formatter(_ format: String, _ tz: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = format
        return f
    }
}
