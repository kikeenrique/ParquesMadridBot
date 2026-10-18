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
        let days = buildDays(current: current, history: loadHistory(from: historyPath), now: now)
        let html = render(days: days)
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

    private static func render(days: [Day]) -> String {
        let idFormat = formatter("yyyy-MM-dd")
        let longFormat = formatter("EEEE, d 'de' MMMM 'de' yyyy")
        let shortFormat = formatter("d MMM")
        let monthFormat = formatter("MMM")
        let dayOfMonth = formatter("d")
        let timeFormat = formatter("HH:mm")

        let parkNames = days.last?.parks.map { "<li>\(escape(shortName($0.name)))</li>" }.joined() ?? ""

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
            <h2>\(longDate.prefix(1).uppercased() + longDate.dropFirst())</h2>
            <p class="note">\(isToday ? "Estado actual." : "Estado al final del día.")</p>
            \(renderGroups(day.parks, timeFormat: timeFormat))
            </section>
            """)
        }

        return """
        <!doctype html>
        <html lang="es">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Parques de Madrid</title>
        <meta name="description" content="Estado de las alertas meteorológicas de los parques de Madrid, día a día.">
        <link rel="stylesheet" href="style.css">
        </head>
        <body>
        <header>
        <h1>Parques de Madrid</h1>
        <p>Alertas meteorológicas de los parques vigilados por el Ayuntamiento. Elige un día en la línea de tiempo.</p>
        <p class="legend"><span><i class="l1"></i>Abierto</span><span><i class="l3"></i>Alerta amarilla</span>\
        <span><i class="l4"></i>Alerta naranja</span><span><i class="l5"></i>Cerrado</span></p>
        <p class="credits">Datos: <a href="https://www.madrid.es/">Ayuntamiento de Madrid</a>. \
        Código: <a href="https://github.com/kikeenrique/ParquesMadridBot">ParquesMadridBot</a>.</p>
        </header>
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
                    item += " <span class=\"horario\">\(escape(horario))</span>"
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
