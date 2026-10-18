import Foundation

/// Builds the static website: one radio button per day drives a pure-CSS timeline.
enum WebsiteGenerator {
    private static let madrid = TimeZone(identifier: "Europe/Madrid")!

    private struct Change {
        let date: Date
        let code: Int
    }

    private struct ParkDay {
        let name: String
        let startCode: Int
        let changes: [Change]
        let horario: String?

        var endCode: Int { changes.last?.code ?? startCode }
        var worstCode: Int { changes.map(\.code).reduce(startCode, max) }
    }

    private struct Day {
        let date: Date
        let parks: [ParkDay]
    }

    static func generate(
        into directory: String,
        statePath: String = "estado_parques.json",
        historyPath: String = "estadisticas_parques.ndjson",
        now: Date = Date()
    ) throws {
        let current = StateManager.loadPreviousState(from: statePath)
        let history = loadHistory(from: historyPath)
        let days = buildDays(current: current, history: history, now: now)
        let lastChange = history.last.flatMap { ISO8601DateFormatter().date(from: $0.detectedAt) }
        let html = render(days: days, lastChange: lastChange)
        let url = URL(fileURLWithPath: directory).appendingPathComponent("index.html")
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - History reconstruction

    private static func loadHistory(from path: String) -> [ChangeEvent] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return text.split(separator: "\n").compactMap { line in
            try? decoder.decode(ChangeEvent.self, from: Data(line.utf8))
        }
    }

    private static func buildDays(current: [String: ParkState], history: [ChangeEvent], now: Date) -> [Day] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = madrid
        let iso = ISO8601DateFormatter()

        var changesByPark: [String: [Change]] = [:]
        var initialCode: [String: Int] = [:]
        for event in history {
            guard current[event.parque] != nil, let date = iso.date(from: event.detectedAt) else { continue }
            if initialCode[event.parque] == nil {
                initialCode[event.parque] = event.fromCode
            }
            changesByPark[event.parque, default: []].append(Change(date: date, code: event.toCode))
        }

        let parks = current.keys.sorted { shortName($0) < shortName($1) }
        let firstDate = changesByPark.values.compactMap(\.first?.date).min() ?? now
        let today = calendar.startOfDay(for: now)

        var codes = parks.reduce(into: [String: Int]()) { $0[$1] = initialCode[$1] ?? current[$1]!.code }
        var cursor = parks.reduce(into: [String: Int]()) { $0[$1] = 0 }
        var days: [Day] = []
        var day = calendar.startOfDay(for: firstDate)

        while day <= today {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let isToday = day == today
            let parkDays = parks.map { park -> ParkDay in
                let all = changesByPark[park] ?? []
                var changes: [Change] = []
                while cursor[park]! < all.count, all[cursor[park]!].date < nextDay {
                    changes.append(all[cursor[park]!])
                    cursor[park]! += 1
                }
                let parkDay = ParkDay(
                    name: park,
                    startCode: codes[park]!,
                    changes: changes,
                    horario: isToday ? current[park]?.horario : nil
                )
                codes[park] = parkDay.endCode
                return parkDay
            }
            days.append(Day(date: day, parks: parkDays))
            day = nextDay
        }
        return days
    }

    // MARK: - Rendering

    private static func shortName(_ name: String) -> String {
        name.hasPrefix("Parque ") ? String(name.dropFirst("Parque ".count)) : name
    }

    private static func levelClass(_ code: Int) -> String {
        if code >= 5 { return "l5" }
        if code == 4 { return "l4" }
        if code == 3 { return "l3" }
        return "l1"
    }

    private static func levelName(_ code: Int) -> String {
        if code >= 5 { return "cerrado" }
        if code == 4 { return "alerta naranja" }
        if code == 3 { return "alerta amarilla" }
        return "abierto"
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = madrid
        formatter.dateFormat = format
        return formatter
    }

    /// "De 00:00 h a 18:00 h" → "00:00–18:00"
    private static func compactSchedule(_ horario: String) -> String {
        let times = horario.split { !$0.isNumber && $0 != ":" }.filter { $0.contains(":") }
        return times.count == 2 ? "\(times[0])–\(times[1])" : horario
    }

    /// Today at a glance: a headline plus one full-colour card per park, most severe first.
    private static func renderNow(_ today: Day, lastChange: Date?) -> String {
        let groups: [(cls: String, singular: String, plural: String, matches: (Int) -> Bool)] = [
            ("l5", "cerrado", "cerrados", { $0 >= 5 }),
            ("l4", "en alerta naranja", "en alerta naranja", { $0 == 4 }),
            ("l3", "en alerta amarilla", "en alerta amarilla", { $0 == 3 }),
            ("l1", "abierto", "abiertos", { $0 < 3 }),
        ]

        let summary = groups.compactMap { group -> String? in
            let count = today.parks.filter { group.matches($0.endCode) }.count
            guard count > 0 else { return nil }
            return "<span class=\"chip \(group.cls)\">\(count) \(count == 1 ? group.singular : group.plural)</span>"
        }

        let cards = today.parks
            .sorted { ($0.endCode, shortName($1.name)) > ($1.endCode, shortName($0.name)) }
            .map { park -> String in
                // Every card has the same three lines: status, name, schedule
                let schedule: String
                if let horario = park.horario {
                    schedule = compactSchedule(horario)
                } else {
                    schedule = park.endCode < 3 ? "Sin alertas" : "Horario no indicado"
                }
                let level = levelName(park.endCode)
                let name = escape(shortName(park.name))
                return """
                <li class="card \(levelClass(park.endCode))">\
                <span class="chip \(levelClass(park.endCode))">\(level.prefix(1).uppercased() + level.dropFirst())</span>\
                <span class="name" title="\(name)">\(name)</span><span class="when">\(escape(schedule))</span></li>
                """
            }
            .joined(separator: "\n")

        let since = lastChange.map {
            "<p class=\"note\">Sin cambios desde el \(formatter("EEEE d 'de' MMMM, 'a las' HH:mm").string(from: $0)).</p>"
        } ?? ""

        return """
        <section class="now" aria-labelledby="now-title">
        <h2 id="now-title">Ahora</h2>
        <p class="summary">\(summary.joined())</p>
        <ul class="cards">
        \(cards)
        </ul>
        \(since)
        </section>
        """
    }

    private static func render(days: [Day], lastChange: Date?) -> String {
        let idFormat = formatter("yyyy-MM-dd")
        let longFormat = formatter("EEEE, d 'de' MMMM 'de' yyyy")
        let shortFormat = formatter("d MMM")
        let monthFormat = formatter("MMM")
        let dayOfMonth = formatter("d")
        let timeFormat = formatter("HH:mm")

        let parkNames = days.last?.parks.map { "<li>\(escape(shortName($0.name)))</li>" }.joined() ?? ""
        // Day blocks are out of the page flow, so each one carries the footer: only the visible day shows it
        let footer = """
        <footer>Datos: <a href="https://www.madrid.es/">Ayuntamiento de Madrid</a>. \
        Código: <a href="https://github.com/kikeenrique/ParquesMadridBot">ParquesMadridBot</a>.</footer>
        """

        var timeline: [String] = []
        // Newest first: the timeline scrolls right-to-left so today is visible without JavaScript
        for day in days.reversed() {
            let id = "d-" + idFormat.string(from: day.date)
            let isToday = day.date == days.last?.date
            let longDate = longFormat.string(from: day.date)
            let cells = day.parks.map { "<i class=\"\(levelClass($0.worstCode))\"></i>" }.joined()
            let startsMonth = dayOfMonth.string(from: day.date) == "1" || day.date == days.first?.date
            let month = startsMonth ? "<b>\(monthFormat.string(from: day.date))</b>" : ""

            timeline.append("""
            <input type="radio" name="dia" id="\(id)"\(isToday ? " checked" : "")>\
            <label for="\(id)" title="\(longDate)">\(month)<span class="vh">\(shortFormat.string(from: day.date))</span>\(cells)</label>
            <section class="day">
            <div class="panel">
            <h2>\(longDate.prefix(1).uppercased() + longDate.dropFirst())</h2>
            \(isToday ? "" : "<p class=\"note\">Estado al final del día.</p>")
            \(renderGroups(day.parks, timeFormat: timeFormat))
            </div>
            \(footer)
            </section>
            """)
        }

        return """
        <!doctype html>
        <html lang="es">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <title>Parques de Madrid</title>
        <meta name="description" content="Estado de las alertas meteorológicas de los parques de Madrid, día a día.">
        <meta name="theme-color" content="#f7f6f2" media="(prefers-color-scheme: light)">
        <meta name="theme-color" content="#161614" media="(prefers-color-scheme: dark)">
        <meta name="apple-mobile-web-app-title" content="Parques">
        <meta name="mobile-web-app-capable" content="yes">
        <link rel="manifest" href="manifest.webmanifest">
        <link rel="apple-touch-icon" href="apple-touch-icon.png">
        <link rel="icon" href="icon-192.png" type="image/png">
        <link rel="stylesheet" href="style.css">
        </head>
        <body>
        <header>
        <img class="banner" src="parques.webp" alt="" width="1536" height="810">
        <h1>Parques de Madrid</h1>
        <p>Alertas meteorológicas de los parques vigilados por el Ayuntamiento de Madrid.</p>
        <p>Recibe cada cambio en Mastodon: \
        <a rel="me" href="https://mastodon.social/@ParquesMadridBot">@ParquesMadridBot@mastodon.social</a></p>
        </header>
        \(days.last.map { renderNow($0, lastChange: lastChange) } ?? "")
        <section class="history" aria-labelledby="history-title">
        <h2 id="history-title">Día a día</h2>
        <p class="legend"><span><i class="l1"></i>Abierto</span><span><i class="l3"></i>Alerta amarilla</span>\
        <span><i class="l4"></i>Alerta naranja</span><span><i class="l5"></i>Cerrado</span></p>
        <p class="hint">Elige un día en la línea de tiempo.</p>
        </section>
        <main class="viewer">
        <ol class="names" aria-hidden="true">\(parkNames)</ol>
        <div class="timeline" role="radiogroup" aria-label="Día">
        \(timeline.joined(separator: "\n"))
        </div>
        </main>
        </body>
        </html>

        """
    }

    private static func renderGroups(_ parks: [ParkDay], timeFormat: DateFormatter) -> String {
        let groups: [(cls: String, header: String, matches: (Int) -> Bool)] = [
            ("l1", "Abiertos", { $0 < 3 }),
            ("l3", "Alerta amarilla", { $0 == 3 }),
            ("l4", "Alerta naranja", { $0 == 4 }),
            ("l5", "Cerrados", { $0 >= 5 }),
        ]

        var html: [String] = []
        for group in groups {
            let members = parks.filter { group.matches($0.endCode) }
            guard !members.isEmpty else { continue }

            let items = members.map { park -> String in
                var item = escape(shortName(park.name))
                if let horario = park.horario, park.endCode >= 4 {
                    item += " <span class=\"horario\">\(escape(compactSchedule(horario)))</span>"
                }
                // Codes 1 and 2 both read as "abierto": only list changes a reader can see
                var lastLevel = levelName(park.startCode)
                var steps = [lastLevel]
                for change in park.changes where levelName(change.code) != lastLevel {
                    lastLevel = levelName(change.code)
                    steps.append("\(lastLevel) (\(timeFormat.string(from: change.date)))")
                }
                if steps.count > 1 {
                    item += "<br><small>\(steps.joined(separator: " → "))</small>"
                }
                return "<li>\(item)</li>"
            }
            html.append("<h3><i class=\"\(group.cls)\"></i>\(group.header)</h3><ul>\(items.joined())</ul>")
        }
        return html.joined(separator: "\n")
    }
}
