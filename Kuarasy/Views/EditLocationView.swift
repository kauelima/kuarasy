import SwiftUI

/// Label, menu bar pin and removal for one location.
struct EditLocationView: View {
    @Environment(ClockStore.self) private var store
    let id: UUID
    let onDone: () -> Void
    @FocusState private var aliasFocused: Bool

    var body: some View {
        if let location = store.locations.first(where: { $0.id == id }) {
            content(location)
        } else {
            Color.clear.frame(height: 1).onAppear(perform: onDone)
        }
    }

    private func content(_ location: Location) -> some View {
        let tz = location.timeZone
        let now = Date()
        let alias = Binding(
            get: { location.alias },
            set: { var copy = location; copy.alias = $0; store.update(copy) }
        )
        let pinned = Binding(
            get: { store.isPinned(location.id) },
            set: { store.pin($0 ? location.id : nil) }
        )
        let counts = Binding(
            get: { location.countsTowardBar },
            set: { store.setCountsTowardBar(location.id, $0) }
        )

        return VStack(spacing: 10) {
            PanelHeader(title: location.cityName, onBack: onDone) {
                Button("Done", action: onDone)
                    .glassButton(prominent: true)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Label").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField("e.g. Design Team, NYC office", text: alias)
                    .textFieldStyle(.plain)
                    .focused($aliasFocused)
                    .onSubmit(onDone)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .glassCapsule()
            }
            .padding(12)
            .glassCard(cornerRadius: 20)

            VStack(spacing: 8) {
                infoRow("Time zone", tz.identifier)
                infoRow("Abbreviation", TimeZoneCatalog.abbreviation(for: tz, at: now))
                infoRow("Offset", TimeMath.utcOffsetLabel(tz, at: now))
                Divider()
                toggleRow("Show in menu bar", isOn: pinned)
                toggleRow("Count toward the bar", isOn: counts)
                    .help("Off: the clock moves below the bar and doesn't affect it")
            }
            .padding(12)
            .glassCard(cornerRadius: 20)

            Button(role: .destructive) {
                store.remove(id: location.id)
                onDone()
            } label: {
                Label("Remove location", systemImage: "trash")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
            }
            .glassButton()
        }
        .onAppear { aliasFocused = true }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Toggle(label, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .font(.callout)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.callout)
    }
}
