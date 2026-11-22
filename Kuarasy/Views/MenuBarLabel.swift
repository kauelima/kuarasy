import SwiftUI

/// The status item: the pinned zone's sun phase and/or time.
/// Driven by the store's minute ticker; menu bar labels don't host `TimelineView` reliably.
struct MenuBarLabel: View {
    let store: ClockStore

    var body: some View {
        let pinned = store.pinnedLocation
        let tz = pinned.timeZone
        let now = store.now
        let symbol = TimeMath.solarPhase(at: now, in: tz).symbol
        let clock = TimeFormat.compact(now, in: tz, use24Hour: store.settings.use24Hour)
        // Always name the zone, so a pinned coworker zone isn't mistaken for local time.
        let time = "\(clock) \(TimeZoneCatalog.abbreviation(for: tz, at: now))"

        switch store.settings.menuBarMode {
        case .icon:
            Image(systemName: symbol)
        case .time:
            Text(time).monospacedDigit()
        case .iconAndTime:
            Text("\(Image(systemName: symbol)) \(time)").monospacedDigit()
        }
    }
}
