import Foundation
import Testing
@testable import Kuarasy

private func tz(_ id: String) -> TimeZone { TimeZone(identifier: id)! }

/// Builds a date from wall-clock components in a given zone.
private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0, in zone: String) -> Date {
    var c = DateComponents()
    (c.year, c.month, c.day, c.hour, c.minute) = (y, mo, d, h, mi)
    return TimeMath.calendar(tz(zone)).date(from: c)!
}

struct OffsetTests {
    @Test func laVersusNewYork() {
        let d = date(2026, 11, 17, 12, in: "UTC")
        let s = TimeMath.offsetSeconds(tz("America/Los_Angeles"), relativeTo: tz("America/New_York"), at: d)
        #expect(TimeMath.relativeOffsetLabel(seconds: s) == "\u{2212}3h")
    }

    @Test func halfAndQuarterHourZones() {
        let d = date(2026, 1, 10, 12, in: "UTC")
        #expect(TimeMath.utcOffsetLabel(tz("Asia/Kolkata"), at: d) == "UTC+5:30")
        #expect(TimeMath.utcOffsetLabel(tz("Asia/Kathmandu"), at: d) == "UTC+5:45")
        let s = TimeMath.offsetSeconds(tz("Asia/Kolkata"), relativeTo: tz("America/Sao_Paulo"), at: d)
        #expect(TimeMath.relativeOffsetLabel(seconds: s) == "+8:30")
    }

    @Test func sameTimeAndUTC() {
        let d = Date()
        #expect(TimeMath.relativeOffsetLabel(seconds: 0) == "Same time")
        #expect(TimeMath.utcOffsetLabel(tz("UTC"), at: d) == "UTC")
    }

    /// US DST: 2026-03-08 springs forward, 2026-11-01 falls back.
    @Test func losAngelesDST() {
        let before = date(2026, 3, 7, 12, in: "UTC")
        let after = date(2026, 3, 9, 12, in: "UTC")
        #expect(TimeMath.utcOffsetLabel(tz("America/Los_Angeles"), at: before) == "UTC\u{2212}8")
        #expect(TimeMath.utcOffsetLabel(tz("America/Los_Angeles"), at: after) == "UTC\u{2212}7")
        #expect(TimeZoneCatalog.abbreviation(for: tz("America/Los_Angeles"), at: before) == "PST")
        #expect(TimeZoneCatalog.abbreviation(for: tz("America/Los_Angeles"), at: after) == "PDT")
        let nov = date(2026, 11, 2, 12, in: "UTC")
        #expect(TimeZoneCatalog.abbreviation(for: tz("America/Los_Angeles"), at: nov) == "PST")
    }

    @Test func curatedAbbreviation() {
        #expect(TimeZoneCatalog.abbreviation(for: tz("America/Sao_Paulo"), at: Date()) == "BRT")
    }

    /// BC, Alberta and Manitoba are on permanent time from 2026-11-01 (IANA 2026f).
    @Test func canadaPermanentTime() {
        for month in [1, 7] {
            let d = date(2027, month, 15, 12, in: "UTC")
            #expect(TimeZoneCatalog.zoneDescription(for: tz("America/Vancouver"), at: d) == "MST · UTC\u{2212}7")
            #expect(TimeZoneCatalog.zoneDescription(for: tz("America/Edmonton"), at: d) == "CST · UTC\u{2212}6")
            #expect(TimeZoneCatalog.zoneDescription(for: tz("America/Winnipeg"), at: d) == "EST · UTC\u{2212}5")
        }
    }

    @Test func legacyAliasesHidden() {
        let ids = Set(TimeZoneCatalog.all.map(\.id))
        #expect(ids.contains("America/Nuuk") && !ids.contains("America/Godthab"))
        #expect(ids.contains("Asia/Yangon") && !ids.contains("Asia/Rangoon"))
    }
}

struct DayRelationTests {
    @Test func tokyoIsTomorrowLateEvening() {
        // 22:00 in São Paulo = 10:00 next day in Tokyo.
        let d = date(2026, 11, 17, 22, in: "America/Sao_Paulo")
        #expect(TimeMath.dayRelation(at: d, in: tz("Asia/Tokyo"), home: tz("America/Sao_Paulo")) == .tomorrow)
    }

    @Test func laIsYesterdayJustAfterMidnight() {
        let d = date(2026, 11, 18, 1, in: "America/Sao_Paulo")
        #expect(TimeMath.dayRelation(at: d, in: tz("America/Los_Angeles"), home: tz("America/Sao_Paulo")) == .yesterday)
    }

    @Test func sameDayAcrossMonthBoundary() {
        let d = date(2026, 12, 31, 12, in: "America/Sao_Paulo")
        #expect(TimeMath.dayRelation(at: d, in: tz("America/New_York"), home: tz("America/Sao_Paulo")) == .today)
        let late = date(2026, 12, 31, 23, in: "America/Sao_Paulo")
        #expect(TimeMath.dayRelation(at: late, in: tz("Europe/London"), home: tz("America/Sao_Paulo")) == .tomorrow)
    }
}

struct StatusTests {
    let hours = WorkingHours()
    let sp = "America/Sao_Paulo"

    @Test func boundaries() {
        // 2026-11-17 is a Tuesday.
        #expect(TimeMath.status(at: date(2026, 11, 17, 8, 59, in: sp), in: tz(sp), hours: hours) == .offHours)
        #expect(TimeMath.status(at: date(2026, 11, 17, 9, 0, in: sp), in: tz(sp), hours: hours) == .working)
        #expect(TimeMath.status(at: date(2026, 11, 17, 17, 59, in: sp), in: tz(sp), hours: hours) == .working)
        #expect(TimeMath.status(at: date(2026, 11, 17, 18, 0, in: sp), in: tz(sp), hours: hours) == .offHours)
        #expect(TimeMath.status(at: date(2026, 11, 17, 21, 59, in: sp), in: tz(sp), hours: hours) == .offHours)
        #expect(TimeMath.status(at: date(2026, 11, 17, 22, 0, in: sp), in: tz(sp), hours: hours) == .sleeping)
        #expect(TimeMath.status(at: date(2026, 11, 17, 6, 59, in: sp), in: tz(sp), hours: hours) == .sleeping)
        #expect(TimeMath.status(at: date(2026, 11, 17, 7, 0, in: sp), in: tz(sp), hours: hours) == .offHours)
    }

    @Test func weekendIsOffHours() {
        // 2026-11-21 is a Saturday.
        #expect(TimeMath.status(at: date(2026, 11, 21, 11, in: sp), in: tz(sp), hours: hours) == .offHours)
    }

    @Test func solarPhases() {
        let z = tz(sp)
        #expect(TimeMath.solarPhase(at: date(2026, 11, 17, 6, in: sp), in: z) == .sunrise)
        #expect(TimeMath.solarPhase(at: date(2026, 11, 17, 12, in: sp), in: z) == .day)
        #expect(TimeMath.solarPhase(at: date(2026, 11, 17, 18, in: sp), in: z) == .sunset)
        #expect(TimeMath.solarPhase(at: date(2026, 11, 17, 23, in: sp), in: z) == .night)
    }
}

struct OverlapTests {
    @Test func saoPauloNewYorkLosAngeles() {
        let home = tz("America/Sao_Paulo")
        let zones = [home, tz("America/New_York"), tz("America/Los_Angeles")]
        let day = TimeMath.day(containing: date(2026, 11, 17, 12, in: "America/Sao_Paulo"), in: home)
        let slots = TimeMath.overlapSlots(day: day, zones: zones, hours: WorkingHours())
        #expect(slots.count == 96)

        // Everyone works when São Paulo is 14:00 to 18:00 (LA 09:00 to 13:00).
        let working = slots.filter { $0.status == .working }.map { TimeMath.minuteOfDay($0.start, in: home) }
        #expect(working.first == 14 * 60)
        #expect(working.last == 17 * 60 + 45)
        #expect(working.count == 16)

        // 11:00 São Paulo = 06:00 LA: someone is asleep.
        let eleven = slots[11 * 4]
        #expect(eleven.status == .sleeping)
    }

    @Test func dstDayHasNinetyTwoSlots() {
        let la = tz("America/Los_Angeles")
        let day = TimeMath.day(containing: date(2026, 3, 8, 12, in: "America/Los_Angeles"), in: la)
        #expect(TimeMath.overlapSlots(day: day, zones: [la], hours: WorkingHours()).count == 92)
    }

    @Test func runsCoverWholeDay() {
        let home = tz("America/Sao_Paulo")
        let day = TimeMath.day(containing: Date(), in: home)
        let runs = TimeMath.runs(TimeMath.overlapSlots(day: day, zones: [home], hours: WorkingHours()), day: day)
        #expect(runs.first?.from == 0)
        #expect(runs.last?.to == 1)
        for (a, b) in zip(runs, runs.dropFirst()) { #expect(a.to == b.from && a.status != b.status) }
    }

    @Test func snapRoundsToQuarterHour() {
        let home = tz("UTC")
        let day = TimeMath.day(containing: date(2026, 11, 17, 0, in: "UTC"), in: home)
        let snapped = TimeMath.snap(date(2026, 11, 17, 10, 52, in: "UTC"), in: day)
        #expect(TimeMath.minuteOfDay(snapped, in: home) == 10 * 60 + 45)
    }
}

struct CatalogTests {
    @Test func searchByAbbreviation() {
        let ids = TimeZoneCatalog.search("est").prefix(5).map(\.id)
        #expect(ids.contains("America/New_York"))
    }

    @Test func searchByCityAndOffset() {
        #expect(TimeZoneCatalog.search("campo").contains { $0.id == "America/Campo_Grande" })
        #expect(TimeZoneCatalog.search("buenos").first?.id == "America/Argentina/Buenos_Aires")
        #expect(TimeZoneCatalog.search("+5:30").contains { $0.city == "Kolkata" })
        #expect(TimeZoneCatalog.search("kolkata").first?.id == "Asia/Calcutta")
        #expect(TimeZoneCatalog.search("kathmandu").count == 1)
    }

    @Test func cityName() {
        #expect(TimeZoneCatalog.cityName(for: "America/Argentina/Buenos_Aires") == "Buenos Aires")
    }
}
