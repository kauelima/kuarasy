import Foundation
import Observation

/// App state: saved locations, settings, and the scrubbed moment (if any).
@Observable
@MainActor
final class ClockStore {
    var locations: [Location] { didSet { save() } }
    var settings: AppSettings { didSet { save() } }

    /// A moment picked on the timeline. `nil` means "now" (live).
    var selectedDate: Date?

    /// Minute-aligned clock, used by the menu bar label (which doesn't
    /// reliably host a `TimelineView`).
    private(set) var now = Date()

    #if DEBUG
    /// Debug preview only (`--now`): a fixed time for the panel, so screenshots can show
    /// a weekday whatever day it really is.
    var debugNow: Date?
    #endif

    /// The current time as the panel shows it.
    func liveDate(_ date: Date = Date()) -> Date {
        #if DEBUG
        debugNow ?? date
        #else
        date
        #endif
    }

    private let defaults: UserDefaults
    private static let locationsKey = "kuarasy.v1.locations"
    private static let settingsKey = "kuarasy.v1.settings"
    private var ticker: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decoder = JSONDecoder()
        let storedSettings = defaults.data(forKey: Self.settingsKey)
            .flatMap { try? decoder.decode(AppSettings.self, from: $0) }
        let storedLocations = defaults.data(forKey: Self.locationsKey)
            .flatMap { try? decoder.decode([Location].self, from: $0) }

        let settings = storedSettings ?? AppSettings()
        self.settings = settings
        self.locations = Self.grouped(storedLocations ?? Self.seed(home: settings.homeTimeZoneID))
        if storedLocations == nil { save() }
        startTicker()
    }

    private static func seed(home: String) -> [Location] {
        ["America/New_York", "America/Los_Angeles"]
            .filter { $0 != home }
            .map { Location(timeZoneID: $0) }
    }

    /// Counted locations first, then reference ones, each keeping its relative order.
    /// Every mutation keeps `locations` in this shape, so array order is screen order.
    private static func grouped(_ list: [Location]) -> [Location] {
        list.filter(\.countsTowardBar) + list.filter { !$0.countsTowardBar }
    }

    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(locations) { defaults.set(data, forKey: Self.locationsKey) }
        if let data = try? encoder.encode(settings) { defaults.set(data, forKey: Self.settingsKey) }
    }

    private func startTicker() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let next = (now.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60 + 60
                let wait = next - now.timeIntervalSinceReferenceDate
                try? await Task.sleep(for: .seconds(wait))
                self?.now = Date()
            }
        }
    }

    // MARK: Derived

    var homeTimeZone: TimeZone { TimeZone(identifier: settings.homeTimeZoneID) ?? .current }

    /// The home zone as a pseudo-location, for rendering the "You" row.
    var homeLocation: Location {
        Location(id: Self.homeID, timeZoneID: settings.homeTimeZoneID, alias: "")
    }

    static let homeID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var pinnedLocation: Location {
        locations.first { $0.id == settings.pinnedLocationID } ?? homeLocation
    }

    /// Locations above the bar, which shape it.
    var countedLocations: [Location] { locations.filter(\.countsTowardBar) }

    /// Locations below the bar: shown for reference, ignored by it.
    var referenceLocations: [Location] { locations.filter { !$0.countsTowardBar } }

    /// Everyone who counts toward the "good time" bar: you plus every counted zone.
    var barZones: [TimeZone] { [homeTimeZone] + countedLocations.map(\.timeZone) }

    var isScrubbing: Bool { selectedDate != nil }

    func displayDate(live: Date) -> Date { selectedDate ?? live }

    // MARK: Mutations

    @discardableResult
    func add(timeZoneID: String) -> Location {
        let location = Location(timeZoneID: timeZoneID)
        locations.insert(location, at: countedLocations.count)
        return location
    }

    func update(_ location: Location) {
        guard let i = locations.firstIndex(where: { $0.id == location.id }) else { return }
        var list = locations
        list[i] = location
        locations = Self.grouped(list)
    }

    func remove(id: UUID) {
        locations.removeAll { $0.id == id }
        if settings.pinnedLocationID == id { settings.pinnedLocationID = nil }
    }

    func move(from source: IndexSet, to destination: Int) {
        var list = locations
        list.move(fromOffsets: source, toOffset: destination)
        locations = Self.grouped(list)
    }

    /// Live drag reorder: `id` takes `targetID`'s place and joins its section.
    /// Within a section the two swap. Across the bar the dragged row lands on the
    /// near edge of the other section, next to the bar.
    func move(_ id: UUID, onto targetID: UUID) {
        guard id != targetID,
              let from = locations.firstIndex(where: { $0.id == id }),
              let to = locations.firstIndex(where: { $0.id == targetID }) else { return }
        var list = locations
        var item = list.remove(at: from)
        let target = list.firstIndex(where: { $0.id == targetID })!
        let crossing = item.countsTowardBar != list[target].countsTowardBar
        let movingDown = to > from
        item.countsTowardBar = list[target].countsTowardBar
        list.insert(item, at: movingDown != crossing ? target + 1 : target)
        locations = Self.grouped(list)
    }

    /// Moves a location above or below the bar, placing it next to the bar.
    func setCountsTowardBar(_ id: UUID, _ counts: Bool) {
        guard let i = locations.firstIndex(where: { $0.id == id }),
              locations[i].countsTowardBar != counts else { return }
        var list = locations
        var item = list.remove(at: i)
        item.countsTowardBar = counts
        list.insert(item, at: list.filter(\.countsTowardBar).count)
        locations = list
    }

    func pin(_ id: UUID?) {
        settings.pinnedLocationID = (id == Self.homeID) ? nil : id
    }

    func isPinned(_ id: UUID) -> Bool {
        id == Self.homeID ? settings.pinnedLocationID == nil : settings.pinnedLocationID == id
    }

    // MARK: Scrubbing

    /// Moves the scrubbed time, staying within today (in your zone) and on slot boundaries.
    func shift(by interval: TimeInterval) {
        let live = liveDate()
        let today = TimeMath.day(containing: live, in: homeTimeZone)
        let base = selectedDate ?? TimeMath.snap(live, in: today)
        let target = base.addingTimeInterval(interval)
        let last = today.end.addingTimeInterval(-Double(TimeMath.slotMinutes * 60))
        selectedDate = min(max(target, today.start), last)
    }

    func resetToNow() { selectedDate = nil }
}
