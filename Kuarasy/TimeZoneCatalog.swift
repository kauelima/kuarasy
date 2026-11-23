import Foundation

/// Searchable list of time zones plus the common abbreviations people actually say.
enum TimeZoneCatalog {
    struct Entry: Identifiable, Hashable, Sendable {
        var id: String          // IANA identifier
        var city: String
        var region: String      // "Pacific Time", "Brasilia Time", or the identifier's region
        var abbreviations: [String]
        var searchText: String  // lowercased haystack
    }

    /// Standard and (optional) daylight abbreviation per zone. Foundation returns
    /// "GMT-3" style strings for most zones outside the US, so we keep our own map.
    /// Checked against IANA tzdata 2026f.
    static let abbreviationMap: [String: (std: String, dst: String?)] = [
        // Americas
        "America/New_York": ("EST", "EDT"), "America/Toronto": ("EST", "EDT"),
        "America/Detroit": ("EST", "EDT"), "America/Chicago": ("CST", "CDT"),
        "America/Denver": ("MST", "MDT"), "America/Phoenix": ("MST", nil),
        "America/Los_Angeles": ("PST", "PDT"),
        // BC, Alberta and Manitoba dropped DST in 2026 and stay on UTC-7, -6 and -5
        // all year. IANA calls these MST, CST and EST. Foundation (ICU) still flags
        // them as daylight time, so they must not get a dst entry.
        "America/Vancouver": ("MST", nil), "America/Edmonton": ("CST", nil),
        "America/Winnipeg": ("EST", nil),
        "America/Anchorage": ("AKST", "AKDT"), "Pacific/Honolulu": ("HST", nil),
        "America/Halifax": ("AST", "ADT"), "America/St_Johns": ("NST", "NDT"),
        "America/Puerto_Rico": ("AST", nil), "America/Mexico_City": ("CST", nil),
        "America/Bogota": ("COT", nil), "America/Lima": ("PET", nil),
        "America/Caracas": ("VET", nil), "America/Santiago": ("CLT", "CLST"),
        "America/Sao_Paulo": ("BRT", nil), "America/Argentina/Buenos_Aires": ("ART", nil),
        "America/Montevideo": ("UYT", nil), "America/Manaus": ("AMT", nil),
        "America/Noronha": ("FNT", nil),
        // Europe
        "Europe/London": ("GMT", "BST"), "Europe/Dublin": ("GMT", "IST"),
        "Europe/Lisbon": ("WET", "WEST"), "Europe/Paris": ("CET", "CEST"),
        "Europe/Berlin": ("CET", "CEST"), "Europe/Madrid": ("CET", "CEST"),
        "Europe/Rome": ("CET", "CEST"), "Europe/Amsterdam": ("CET", "CEST"),
        "Europe/Brussels": ("CET", "CEST"), "Europe/Zurich": ("CET", "CEST"),
        "Europe/Vienna": ("CET", "CEST"), "Europe/Stockholm": ("CET", "CEST"),
        "Europe/Oslo": ("CET", "CEST"), "Europe/Copenhagen": ("CET", "CEST"),
        "Europe/Warsaw": ("CET", "CEST"), "Europe/Prague": ("CET", "CEST"),
        "Europe/Budapest": ("CET", "CEST"), "Europe/Athens": ("EET", "EEST"),
        "Europe/Helsinki": ("EET", "EEST"), "Europe/Kyiv": ("EET", "EEST"),
        "Europe/Bucharest": ("EET", "EEST"), "Europe/Istanbul": ("TRT", nil),
        "Europe/Moscow": ("MSK", nil),
        // Africa & Middle East
        "Africa/Lagos": ("WAT", nil), "Africa/Cairo": ("EET", "EEST"),
        "Africa/Johannesburg": ("SAST", nil), "Africa/Nairobi": ("EAT", nil),
        "Asia/Jerusalem": ("IST", "IDT"), "Asia/Riyadh": ("AST", nil),
        "Asia/Dubai": ("GST", nil),
        // Asia & Pacific
        "Asia/Karachi": ("PKT", nil), "Asia/Kolkata": ("IST", nil), "Asia/Calcutta": ("IST", nil),
        "Asia/Kathmandu": ("NPT", nil), "Asia/Dhaka": ("BST", nil),
        "Asia/Bangkok": ("ICT", nil), "Asia/Ho_Chi_Minh": ("ICT", nil),
        "Asia/Jakarta": ("WIB", nil), "Asia/Singapore": ("SGT", nil),
        "Asia/Kuala_Lumpur": ("MYT", nil), "Asia/Manila": ("PHT", nil),
        "Asia/Hong_Kong": ("HKT", nil), "Asia/Shanghai": ("CST", nil),
        "Asia/Taipei": ("CST", nil), "Asia/Seoul": ("KST", nil),
        "Asia/Tokyo": ("JST", nil), "Australia/Perth": ("AWST", nil),
        "Australia/Adelaide": ("ACST", "ACDT"), "Australia/Darwin": ("ACST", nil),
        "Australia/Brisbane": ("AEST", nil), "Australia/Sydney": ("AEST", "AEDT"),
        "Australia/Melbourne": ("AEST", "AEDT"), "Pacific/Auckland": ("NZST", "NZDT"),
        // Generic
        "UTC": ("UTC", nil), "GMT": ("GMT", nil),
    ]

    /// Foundation still lists some zones under old names; show the current city.
    /// Also restores accents that IANA identifiers drop.
    static let cityOverrides = [
        "Asia/Calcutta": "Kolkata",
        "America/Sao_Paulo": "São Paulo",
        "America/Bogota": "Bogotá",
        "America/Asuncion": "Asunción",
        "America/Cancun": "Cancún",
        "America/Merida": "Mérida",
        "America/Mazatlan": "Mazatlán",
        "America/Ciudad_Juarez": "Ciudad Juárez",
        "America/Belem": "Belém",
        "America/Maceio": "Maceió",
        "America/Araguaina": "Araguaína",
        "America/Cuiaba": "Cuiabá",
        "America/Santarem": "Santarém",
        "America/Eirunepe": "Eirunepé",
        "America/Curacao": "Curaçao",
        "Europe/Zurich": "Zürich",
        "America/Montreal": "Montréal",
        "Asia/Ho_Chi_Minh": "Ho Chi Minh City",
        // Spellings from IANA's zone1970.tab and iso3166.tab.
        "America/Argentina/Tucuman": "Tucumán",
        "America/Bahia_Banderas": "Bahía de Banderas",
        "Pacific/Galapagos": "Galápagos",
        "Asia/Aqtobe": "Aqtöbe",
        "Europe/Busingen": "Büsingen",
        "Indian/Reunion": "Réunion",
    ]
    /// Legacy duplicates of zones that are also listed under their modern name.
    /// IANA's `backward` file lists these as "alternate names for the same location".
    static let hiddenIdentifiers: Set<String> = [
        "Asia/Katmandu", "Europe/Kiev", "America/Godthab", "Asia/Rangoon",
        "Pacific/Ponape", "Pacific/Truk",
    ]

    static func cityName(for identifier: String) -> String {
        if let override = cityOverrides[identifier] { return override }
        let last = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// Abbreviation in effect at `date`: curated, then Foundation's short name.
    static func abbreviation(for tz: TimeZone, at date: Date) -> String {
        if let entry = abbreviationMap[tz.identifier] {
            if tz.isDaylightSavingTime(for: date), let dst = entry.dst { return dst }
            return entry.std
        }
        let utc = TimeMath.utcOffsetLabel(tz, at: date)
        // Foundation's fallback is "GMT+3", which only repeats the offset.
        guard let foundation = tz.abbreviation(for: date),
              !(foundation.hasPrefix("GMT") && foundation.count > 3) else { return utc }
        return foundation
    }

    /// "EST · UTC−5", or just "UTC+3" when the zone has no common abbreviation.
    static func zoneDescription(for tz: TimeZone, at date: Date) -> String {
        let abbrev = abbreviation(for: tz, at: date)
        let utc = TimeMath.utcOffsetLabel(tz, at: date)
        return abbrev == utc ? utc : "\(abbrev) · \(utc)"
    }

    static func regionName(for tz: TimeZone) -> String {
        if let generic = tz.localizedName(for: .generic, locale: Locale(identifier: "en_US")) {
            return generic
        }
        return tz.identifier.split(separator: "/").first.map(String.init) ?? tz.identifier
    }

    static let all: [Entry] = {
        let now = Date()
        return TimeZone.knownTimeZoneIdentifiers.compactMap { id -> Entry? in
            guard !hiddenIdentifiers.contains(id), let tz = TimeZone(identifier: id) else { return nil }
            let city = cityName(for: id)
            let region = regionName(for: tz)
            var abbrevs: [String] = []
            if let pair = abbreviationMap[id] {
                abbrevs.append(pair.std)
                if let dst = pair.dst { abbrevs.append(dst) }
            } else if let a = tz.abbreviation(for: now), !a.hasPrefix("GMT") {
                abbrevs.append(a)
            }
            let offset = TimeMath.utcOffsetLabel(tz, at: now)
            let haystack = [id, city, region, offset, offset.replacingOccurrences(of: "\u{2212}", with: "-")]
                .joined(separator: " ").lowercased()
                .folding(options: .diacriticInsensitive, locale: nil)
            return Entry(id: id, city: city, region: region, abbreviations: abbrevs, searchText: haystack)
        }
        .sorted { $0.city < $1.city }
    }()

    /// Matches city, region, identifier, abbreviation ("est") or offset ("+5:30", "utc-3").
    static func search(_ query: String) -> [Entry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .folding(options: .diacriticInsensitive, locale: nil)
        guard !q.isEmpty else { return all }

        func rank(_ e: Entry) -> Int? {
            if e.abbreviations.contains(where: { $0.lowercased() == q }) { return 0 }
            if e.city.lowercased().folding(options: .diacriticInsensitive, locale: nil).hasPrefix(q) { return 1 }
            if e.region.lowercased().hasPrefix(q) { return 2 }
            if e.searchText.contains(q) { return 3 }
            if q.first == "+" || q.first == "-", e.searchText.contains("utc" + q) { return 3 }
            return nil
        }
        var ranked: [(entry: Entry, rank: Int)] = []
        for entry in all {
            if let r = rank(entry) { ranked.append((entry, r)) }
        }
        ranked.sort { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            return a.entry.city < b.entry.city
        }
        return ranked.map { $0.entry }
    }
}
