import SwiftUI

/// One clock card: solar icon, name, zone details, time and working status.
struct LocationRow: View {
    @Environment(ClockStore.self) private var store
    let location: Location
    let isHome: Bool
    let date: Date
    @Binding var route: Route

    @State private var hovering = false

    var body: some View {
        let tz = location.timeZone
        let home = store.homeTimeZone
        let use24 = store.settings.use24Hour
        let status = TimeMath.status(at: date, in: tz, hours: store.settings.hours)
        let phase = TimeMath.solarPhase(at: date, in: tz)

        HStack(spacing: 12) {
            Image(systemName: phase.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
                .glassCard(cornerRadius: 18, tint: phase.color.opacity(0.3))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(location.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if isHome {
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .glassCapsule(tint: .accentColor.opacity(0.5))
                    }
                    if store.isPinned(location.id) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("Shown in the menu bar")
                    }
                }
                Text(zoneLine(tz))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(relationLine(tz, home: home))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(TimeFormat.time(date, in: tz, use24Hour: use24))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if let period = TimeFormat.period(date, in: tz, use24Hour: use24) {
                        Text(period)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Label(status.label, systemImage: status.symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(status.color)
                    .labelStyle(.titleAndIcon)
            }

            LocationMenuButton(location: location, isHome: isHome, route: $route)
                .opacity(hovering ? 1 : 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 9)
        .glassCard(cornerRadius: 20, tint: status.color.opacity(0.10))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu { LocationMenuItems(location: location, isHome: isHome, route: $route) }
    }

    private func zoneLine(_ tz: TimeZone) -> String {
        let zone = TimeZoneCatalog.zoneDescription(for: tz, at: date)
        if isHome { return location.alias.isEmpty ? zone : "\(location.cityName) · \(zone)" }
        if let city = location.subtitle { return "\(city) · \(zone)" }
        return zone
    }

    private func relationLine(_ tz: TimeZone, home: TimeZone) -> String {
        if isHome { return TimeFormat.shortDay(date, in: tz) }
        let day = TimeMath.dayRelation(at: date, in: tz, home: home)
        let offset = TimeMath.relativeOffsetLabel(seconds: TimeMath.offsetSeconds(tz, relativeTo: home, at: date))
        return "\(day.label) · \(offset)"
    }
}
