import SwiftUI

/// Searchable time zone list, used both to add a location and to choose your own zone.
struct ZonePickerView: View {
    let title: String
    let onPick: (String) -> Void
    let onCancel: () -> Void

    @Environment(ClockStore.self) private var store
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        let results = Array(TimeZoneCatalog.search(query).prefix(200))

        VStack(spacing: 10) {
            PanelHeader(title: title, onBack: onCancel)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("City, abbreviation (EST) or offset (+5:30)", text: $query)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { if let first = results.first { onPick(first.id) } }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassCapsule()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results) { entry in
                        ZoneResultRow(entry: entry, use24Hour: store.settings.use24Hour) {
                            onPick(entry.id)
                        }
                    }
                }
                .padding(4)
            }
            .frame(height: 380)
            .glassCard(cornerRadius: 20)
            .overlay {
                if results.isEmpty {
                    Text("No matching time zones").foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { focused = true }
    }
}

private struct ZoneResultRow: View {
    let entry: TimeZoneCatalog.Entry
    let use24Hour: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let tz = TimeZone(identifier: entry.id) ?? .current
        let now = Date()
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.city).font(.system(size: 13, weight: .medium))
                    Text(entry.region).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(TimeFormat.compact(now, in: tz, use24Hour: use24Hour))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                    Text(TimeZoneCatalog.zoneDescription(for: tz, at: now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(hovering ? Color.primary.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
