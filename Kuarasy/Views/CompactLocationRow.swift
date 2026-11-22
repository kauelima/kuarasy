import SwiftUI

/// A reference clock below the bar: about half the height of `LocationRow`, no status
/// colours. It follows the scrubbed time but doesn't affect the bar.
struct CompactLocationRow: View {
    @Environment(ClockStore.self) private var store
    let location: Location
    let date: Date
    @Binding var route: Route

    @State private var hovering = false

    var body: some View {
        let tz = location.timeZone
        let home = store.homeTimeZone
        let use24 = store.settings.use24Hour
        let day = TimeMath.dayRelation(at: date, in: tz, home: home)

        HStack(spacing: 8) {
            Image(systemName: TimeMath.solarPhase(at: date, in: tz).symbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(location.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .layoutPriority(1)
            if store.isPinned(location.id) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .help("Shown in the menu bar")
            }
            Text(detailLine(tz, home: home))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            if day != .today {
                Text(day.label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(TimeFormat.time(date, in: tz, use24Hour: use24))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let period = TimeFormat.period(date, in: tz, use24Hour: use24) {
                    Text(period)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            LocationMenuButton(location: location, isHome: false, route: $route)
                .opacity(hovering ? 1 : 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 36)
        .glassCard(cornerRadius: 14)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu { LocationMenuItems(location: location, isHome: false, route: $route) }
    }

    /// "IST · +8:30", or "Kolkata · IST · +8:30" when the title is an alias.
    private func detailLine(_ tz: TimeZone, home: TimeZone) -> String {
        let abbreviation = TimeZoneCatalog.abbreviation(for: tz, at: date)
        let offset = TimeMath.relativeOffsetLabel(seconds: TimeMath.offsetSeconds(tz, relativeTo: home, at: date))
        return ([location.subtitle, abbreviation, offset].compactMap { $0 }).joined(separator: " · ")
    }
}

/// The ⋯ button shown on hover over a row.
struct LocationMenuButton: View {
    let location: Location
    let isHome: Bool
    @Binding var route: Route

    var body: some View {
        Menu { LocationMenuItems(location: location, isHome: isHome, route: $route) } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 18, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// Shared by the ⋯ menu and the context menu of both row styles.
struct LocationMenuItems: View {
    @Environment(ClockStore.self) private var store
    let location: Location
    let isHome: Bool
    @Binding var route: Route

    var body: some View {
        if !store.isPinned(location.id) {
            Button("Show in Menu Bar", systemImage: "pin") { store.pin(location.id) }
        }
        if isHome {
            Button("Change Your Time Zone…", systemImage: "location") { route = .pickHome }
        } else {
            if location.countsTowardBar {
                Button("Show Without Counting", systemImage: "arrow.down.to.line") {
                    withAnimation(.snappy(duration: 0.2)) { store.setCountsTowardBar(location.id, false) }
                }
            } else {
                Button("Count Toward Bar", systemImage: "arrow.up.to.line") {
                    withAnimation(.snappy(duration: 0.2)) { store.setCountsTowardBar(location.id, true) }
                }
            }
            Button("Edit…", systemImage: "pencil") { route = .edit(location.id) }
            Divider()
            Button("Remove", systemImage: "trash", role: .destructive) { store.remove(id: location.id) }
        }
    }
}
