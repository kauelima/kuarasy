import SwiftUI

struct SettingsView: View {
    @Environment(ClockStore.self) private var store
    @Binding var route: Route
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        @Bindable var store = store
        let home = store.homeTimeZone
        let now = Date()

        VStack(spacing: 10) {
            PanelHeader(title: "Settings") { route = .list }

            VStack(spacing: 10) {
                section("Your time zone") {
                    Button {
                        route = .pickHome
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(TimeZoneCatalog.cityName(for: home.identifier))
                                    .font(.system(size: 13, weight: .medium))
                                Text(TimeZoneCatalog.zoneDescription(for: home, at: now))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if home.identifier != TimeZone.current.identifier {
                        Button("Use this Mac's time zone (\(TimeZoneCatalog.cityName(for: TimeZone.current.identifier)))") {
                            store.settings.homeTimeZoneID = TimeZone.current.identifier
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }

                section("General") {
                    HStack {
                        Text("Time format")
                        Spacer()
                        Picker("Time format", selection: $store.settings.use24Hour) {
                            Text("12-hour").tag(false)
                            Text("24-hour").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    HStack {
                        Text("Open at login")
                        Spacer()
                        Toggle("Open at login", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { _, enabled in
                                LaunchAtLogin.set(enabled)
                                launchAtLogin = LaunchAtLogin.isEnabled
                            }
                    }
                }

                section("Menu bar") {
                    Picker("Show", selection: Binding(
                        get: { store.pinnedLocation.id },
                        set: { store.pin($0) }
                    )) {
                        Text("You (\(TimeZoneCatalog.cityName(for: home.identifier)))").tag(ClockStore.homeID)
                        ForEach(store.locations) { Text($0.title).tag($0.id) }
                    }
                    Picker("Display", selection: $store.settings.menuBarMode) {
                        ForEach(MenuBarMode.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                section("Working hours") {
                    HStack {
                        MinutePicker(label: "From", minutes: $store.settings.hours.start)
                        MinutePicker(label: "To", minutes: $store.settings.hours.end)
                    }
                    WorkdayPicker(workdays: $store.settings.hours.workdays)
                }

                section("Sleeping hours") {
                    HStack {
                        MinutePicker(label: "From", minutes: $store.settings.hours.sleepStart)
                        MinutePicker(label: "To", minutes: $store.settings.hours.sleepEnd)
                    }
                    Text("Used for every location. Red on the bar means someone is asleep.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit Kuarasy", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .glassButton()
                .keyboardShortcut("q")
            }
        }
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(cornerRadius: 20)
    }
}

/// Quarter-hour time picker, formatted with the app's 12h/24h setting.
private struct MinutePicker: View {
    @Environment(ClockStore.self) private var store
    let label: String
    @Binding var minutes: Int

    var body: some View {
        Picker(label, selection: $minutes) {
            ForEach(Array(stride(from: 0, to: 24 * 60, by: 15)), id: \.self) { m in
                Text(Self.format(m, use24Hour: store.settings.use24Hour)).tag(m)
            }
        }
        .pickerStyle(.menu)
    }

    static func format(_ minutes: Int, use24Hour: Bool) -> String {
        let h = minutes / 60, m = minutes % 60
        if use24Hour { return String(format: "%02d:%02d", h, m) }
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", h12, m, h < 12 ? "AM" : "PM")
    }
}

/// Mon to Sun toggles.
private struct WorkdayPicker: View {
    @Binding var workdays: Set<Int>
    // Calendar weekdays starting Monday.
    private let days: [(Int, String)] = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { day, letter in
                let on = workdays.contains(day)
                Button {
                    if on { workdays.remove(day) } else { workdays.insert(day) }
                } label: {
                    Text(letter)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 24)
                        .foregroundStyle(on ? .primary : .secondary)
                        .glassCapsule(tint: on ? TimeStatus.working.color.opacity(0.6) : nil, interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
