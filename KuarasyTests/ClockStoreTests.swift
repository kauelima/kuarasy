import Foundation
import Testing
@testable import Kuarasy

@MainActor
struct ClockStoreTests {
    private func freshDefaults() -> UserDefaults {
        let name = "kuarasy.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func seedsAndPersists() {
        let defaults = freshDefaults()
        let store = ClockStore(defaults: defaults)
        store.settings.homeTimeZoneID = "America/Sao_Paulo"
        let tokyo = store.add(timeZoneID: "Asia/Tokyo")
        var renamed = tokyo
        renamed.alias = "Tokyo team"
        store.update(renamed)
        store.pin(tokyo.id)

        let reloaded = ClockStore(defaults: defaults)
        #expect(reloaded.settings.homeTimeZoneID == "America/Sao_Paulo")
        #expect(reloaded.locations.last?.title == "Tokyo team")
        #expect(reloaded.pinnedLocation.id == tokyo.id)
    }

    @Test func reorderAndRemove() {
        let store = ClockStore(defaults: freshDefaults())
        store.locations = [Location(timeZoneID: "Europe/London"),
                           Location(timeZoneID: "Asia/Tokyo"),
                           Location(timeZoneID: "America/Chicago")]
        store.move(from: IndexSet(integer: 0), to: 3)
        #expect(store.locations.map(\.cityName) == ["Tokyo", "Chicago", "London"])

        let chicago = store.locations[1]
        store.pin(chicago.id)
        store.remove(id: chicago.id)
        #expect(store.locations.count == 2)
        #expect(store.settings.pinnedLocationID == nil)
        #expect(store.pinnedLocation.id == ClockStore.homeID)
    }

    @Test func scrubbing() {
        let store = ClockStore(defaults: freshDefaults())
        #expect(!store.isScrubbing)
        store.shift(by: 15 * 60)
        #expect(store.isScrubbing)
        store.resetToNow()
        #expect(store.selectedDate == nil)
    }

    @Test func referenceLocationsStayOutOfTheBar() {
        let store = ClockStore(defaults: freshDefaults())
        store.settings.homeTimeZoneID = "America/Sao_Paulo"
        store.locations = [Location(timeZoneID: "America/New_York"),
                           Location(timeZoneID: "Asia/Kolkata")]
        let kolkata = store.locations[1]
        store.setCountsTowardBar(kolkata.id, false)
        #expect(store.referenceLocations.map(\.id) == [kolkata.id])
        #expect(store.barZones.map(\.identifier) == ["America/Sao_Paulo", "America/New_York"])

        // New locations count, and land above the reference ones.
        let london = store.add(timeZoneID: "Europe/London")
        #expect(store.locations.map(\.id).last == kolkata.id)
        #expect(store.countedLocations.last?.id == london.id)
    }

    @Test func draggingAcrossTheBar() {
        let store = ClockStore(defaults: freshDefaults())
        let ny = Location(timeZoneID: "America/New_York")
        let la = Location(timeZoneID: "America/Los_Angeles")
        let in1 = Location(timeZoneID: "Asia/Kolkata", countsTowardBar: false)
        let tk = Location(timeZoneID: "Asia/Tokyo", countsTowardBar: false)
        store.locations = [ny, la, in1, tk]

        // Down across the bar: lands at the top of the reference rows.
        store.move(la.id, onto: tk.id)
        #expect(store.countedLocations.map(\.id) == [ny.id])
        #expect(store.referenceLocations.map(\.id) == [in1.id, la.id, tk.id])

        // Up across the bar: lands at the bottom of the counted rows.
        store.move(tk.id, onto: ny.id)
        #expect(store.countedLocations.map(\.id) == [ny.id, tk.id])
        #expect(store.referenceLocations.map(\.id) == [in1.id, la.id])

        // Within a section: a plain swap.
        store.move(la.id, onto: in1.id)
        #expect(store.referenceLocations.map(\.id) == [la.id, in1.id])
    }

    @Test func oldSavedLocationsDecodeAsCounting() throws {
        let json = #"[{"id":"\#(UUID().uuidString)","timeZoneID":"Asia/Tokyo","alias":"","cityName":"Tokyo"}]"#
        let decoded = try JSONDecoder().decode([Location].self, from: Data(json.utf8))
        #expect(decoded.first?.countsTowardBar == true)
    }
}
