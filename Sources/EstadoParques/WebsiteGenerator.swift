import Foundation

/// Builds the static website: one radio button per day drives a pure-CSS timeline.
enum WebsiteGenerator {
    private static let madrid = TimeZone(identifier: "Europe/Madrid")!

    private struct Change {
        let date: Date
        let code: Int
        let horario: String?
    }

    private struct ParkDay {
        let name: String
        let startCode: Int
        let changes: [Change]
        let horario: String?
        /// Date the hours refer to; known for today only
        var fecha: String? = nil

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
        var initialHorario: [String: String] = [:]
        for event in history {
            guard current[event.parque] != nil, let date = iso.date(from: event.detectedAt) else { continue }
            if initialCode[event.parque] == nil {
                initialCode[event.parque] = event.fromCode
                initialHorario[event.parque] = event.fromHorario
            }
            changesByPark[event.parque, default: []].append(
                Change(date: date, code: event.toCode, horario: event.toHorario)
            )
        }

        let parks = current.keys.sorted { shortName($0) < shortName($1) }
        let firstDate = changesByPark.values.compactMap(\.first?.date).min() ?? now
        let today = calendar.startOfDay(for: now)

        var codes = parks.reduce(into: [String: Int]()) { $0[$1] = initialCode[$1] ?? current[$1]!.code }
        // Events logged before schedules were tracked carry none, so older days have no hours
        var horarios = initialHorario
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
                    horarios[park] = all[cursor[park]!].horario
                    cursor[park]! += 1
                }
                let parkDay = ParkDay(
                    name: park,
                    startCode: codes[park]!,
                    changes: changes,
                    horario: isToday ? current[park]?.horario : horarios[park],
                    fecha: isToday ? current[park]?.fecha : nil
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

    /// Card pictures in website/parks/
    private static let parkImages: [String: String] = [
        "Jardines del Buen Retiro": "retiro",
        "Jardín del Capricho de la Alameda de Osuna": "capricho",
        "Parque Juan Carlos I": "juan-carlos-i",
        "Parque Juan Pablo II": "juan-pablo-ii",
        "Parque Lineal del Manzanares": "lineal-manzanares",
        "Parque Quinta Fuente del Berro": "fuente-del-berro",
        "Parque Quinta de Torre Arias": "torre-arias",
        "Parque Quinta de los Molinos": "quinta-molinos",
        "Rosaleda del Parque del Oeste": "rosaleda",
    ]

    /// "De 00:00 h a 18:00 h" → "00:00–18:00"
    static func compactSchedule(_ horario: String) -> String {
        let times = horario.split { !$0.isNumber && $0 != ":" }.filter { $0.contains(":") }
        return times.count == 2 ? "\(times[0])–\(times[1])" : horario
    }

    /// "De 18:00 h a 09:00 h" on "18/10/2026" → ["Dom 18, 18:00", "lun 19, 09:00"]: an end at or before the
    /// start runs into the next day. Same-day hours give one part, "Dom 18, 09:00–18:00". Without a usable
    /// date, falls back to the bare hours.
    static func scheduleWithDays(_ horario: String, fecha: String?) -> [String] {
        let times = horario.split { !$0.isNumber && $0 != ":" }.filter { $0.contains(":") }.map(String.init)
        let parser = formatter("dd/MM/yyyy")
        guard times.count == 2, let fecha, let start = parser.date(from: String(fecha.prefix(10))) else {
            return [compactSchedule(horario)]
        }
        let dayFormat = formatter("EEE d")
        // es_ES abbreviates "dom." with a dot; the comma that follows is enough
        func day(_ date: Date) -> String { dayFormat.string(from: date).replacingOccurrences(of: ".", with: "") }
        let startDay = day(start)
        let label = startDay.prefix(1).uppercased() + startDay.dropFirst()
        // "24:00" sorts after any other time, so 21:00–24:00 stays on one day
        guard times[1] <= times[0] else { return ["\(label), \(times[0])–\(times[1])"] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = madrid
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return ["\(label), \(times[0])", "\(day(end)), \(times[1])"]
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
                let schedule: [String]
                if let horario = park.horario, park.endCode >= 3 {
                    schedule = scheduleWithDays(horario, fecha: park.fecha)
                } else {
                    schedule = [park.endCode < 3 ? "Sin alertas" : "Horario no indicado"]
                }
                let when = schedule.map { "<span>\(escape($0))</span>" }.joined(separator: " – ")
                let level = levelName(park.endCode)
                let name = escape(shortName(park.name))
                let photo = parkImages[park.name].map {
                    "<img class=\"photo\" src=\"parks/\($0).webp\" alt=\"\" width=\"144\" height=\"125\">"
                } ?? ""
                return """
                <li class="card \(levelClass(park.endCode))">\(photo)<div class="text">\
                <span class="chip \(levelClass(park.endCode))">\(level.prefix(1).uppercased() + level.dropFirst())</span>\
                <span class="name" title="\(name)">\(name)</span><span class="when">\(when)</span></div></li>
                """
            }
            .joined(separator: "\n")

        let since = lastChange.map {
            "<p class=\"note\">Sin cambios desde el \(formatter("EEEE d 'de' MMMM, 'a las' HH:mm").string(from: $0)).</p>"
        } ?? ""

        return """
        <section class="now" aria-labelledby="now-title">
        <h2 id="now-title">Ahora</h2>
        \(since)
        <p class="summary">\(summary.joined())</p>
        <ul class="cards">
        \(cards)
        </ul>
        <p class="credit">Ilustraciones generadas con IA, con licencia \
        <a href="https://github.com/kikeenrique/ParquesMadridBot/blob/main/resources/parks/LICENSE.md" \
        rel="license">CC BY-SA 4.0</a>.</p>
        </section>
        """
    }

    // Icons defined once and referenced with <use>: the buttons repeat in every day's footer.
    // Zero-size and out of flow: SVG ignores `hidden`, and an unsized <svg> takes 300×150 px of the page.
    // Mastodon logo from Simple Icons (CC0)
    private static let iconSprite = """
    <svg width="0" height="0" style="position: absolute" aria-hidden="true"><symbol id="i-mastodon" viewBox="0 0 24 24"><path fill="currentColor" d="M23.268 5.313c-.35-2.578-2.617-4.61-5.304-5.004\
    C17.51.242 15.792 0 11.813 0h-.03c-3.98 0-4.835.242-5.288.309C3.882.692 1.496 2.518.917 5.127.64 6.412.61 7.837.661 9.143\
    c.074 1.874.088 3.745.26 5.611.118 1.24.325 2.47.62 3.68.55 2.237 2.777 4.098 4.96 4.857 2.336.792 4.849.923 7.256.38\
    .265-.061.527-.132.786-.213.585-.184 1.27-.39 1.774-.753a.057.057 0 0 0 .023-.043v-1.809a.052.052 0 0 0-.02-.041\
    .053.053 0 0 0-.046-.01 20.282 20.282 0 0 1-4.709.545c-2.73 0-3.463-1.284-3.674-1.818a5.593 5.593 0 0 1-.319-1.433\
    .053.053 0 0 1 .066-.054c1.517.363 3.072.546 4.632.546.376 0 .75 0 1.125-.01 1.57-.044 3.224-.124 4.768-.422\
    .038-.008.077-.015.11-.024 2.435-.464 4.753-1.92 4.989-5.604.008-.145.03-1.52.03-1.67.002-.512.167-3.63-.024-5.545z\
    m-3.748 9.195h-2.561V8.29c0-1.309-.55-1.976-1.67-1.976-1.23 0-1.846.79-1.846 2.35v3.403h-2.546V8.663\
    c0-1.56-.617-2.35-1.848-2.35-1.112 0-1.668.668-1.67 1.977v6.218H4.822V8.102c0-1.31.337-2.35 1.011-3.12\
    .696-.77 1.608-1.164 2.74-1.164 1.311 0 2.302.5 2.962 1.498l.638 1.06.638-1.06c.66-.999 1.65-1.498 2.96-1.498 \
    1.13 0 2.043.395 2.74 1.164.675.77 1.012 1.81 1.012 3.12z"/></symbol>\
    <symbol id="i-install" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-width="2" \
    stroke-linecap="round"><rect x="4" y="4" width="16" height="16" rx="4"/><path d="M12 8v8M8 12h8"/></g></symbol></svg>
    """

    private static let actions = """
    <nav class="actions">
    <a class="btn mastodon" rel="me" href="https://mastodon.social/@ParquesMadridBot">\
    <svg aria-hidden="true"><use href="#i-mastodon"/></svg>\
    <span>Síguenos en Mastodon<small>@ParquesMadridBot@mastodon.social</small></span></a>
    <button class="btn install" popovertarget="instalar"><svg aria-hidden="true"><use href="#i-install"/></svg>\
    <span>Instalar como app<small>iPhone, iPad, Mac y Android</small></span></button>
    </nav>
    """

    // The iOS share symbol (square with an up arrow), as Safari draws it
    private static let shareIcon = """
    <svg class="inline-icon" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" \
    stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12M8 7l4-4 4 4"/>\
    <path d="M8 10H6.5A1.5 1.5 0 0 0 5 11.5v8A1.5 1.5 0 0 0 6.5 21h11a1.5 1.5 0 0 0 1.5-1.5v-8A1.5 1.5 0 0 0 17.5 10H16"/></svg>
    """

    private static func render(days: [Day], lastChange: Date?) -> String {
        let idFormat = formatter("yyyy-MM-dd")
        let longFormat = formatter("EEEE, d 'de' MMMM 'de' yyyy")
        let shortFormat = formatter("d MMM")
        let monthFormat = formatter("MMM")
        let dayOfMonth = formatter("d")
        let timeFormat = formatter("HH:mm")

        let parkNames = days.last?.parks.map { "<li>\(escape(shortName($0.name)))</li>" }.joined() ?? ""
        // Day blocks are out of the page flow, so each one carries the footer: only the visible day shows it
        // Repeated per day, but gzip on GitHub Pages makes the copies almost free
        let footer = """
        <footer>\(actions)
        <p>Datos: <a href="https://www.madrid.es/">Ayuntamiento de Madrid</a>. \
        Código: <a href="https://github.com/kikeenrique/ParquesMadridBot">ParquesMadridBot</a>.</p>
        <p class="cookies">🍪 Esta web no usa cookies: ni de las que te rastrean ni de las de chocolate. \
        Lamentamos profundamente no poder interrumpirte con un banner gigante pidiéndote permiso \
        para algo que no vamos a hacer.</p></footer>
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
        <link rel="me" href="https://mastodon.social/@ParquesMadridBot">
        <link rel="manifest" href="manifest.webmanifest">
        <link rel="apple-touch-icon" href="apple-touch-icon.png">
        <link rel="icon" href="icon-192.png" type="image/png">
        <link rel="stylesheet" href="style.css">
        </head>
        <body>
        \(iconSprite)
        <header>
        <img class="banner" src="parques.webp" alt="" width="1536" height="810">
        <h1>Parques de Madrid</h1>
        <p>Alertas meteorológicas de los parques vigilados por el Ayuntamiento de Madrid.</p>
        </header>
        <div id="instalar" popover>
        <h2>Instálala como app</h2>
        <ol>
        <li><b>iPhone y iPad (Safari):</b> pulsa \(shareIcon) <b>Compartir</b> y luego <b>Añadir a pantalla de inicio</b>.</li>
        <li><b>Mac (Safari):</b> menú <b>Archivo → Añadir al Dock</b>.</li>
        <li><b>Android (Chrome):</b> menú ⋮ → <b>Instalar aplicación</b>.</li>
        </ol>
        <p>Sin tienda, sin cuenta y sin permisos: es esta misma web, a pantalla completa y con su icono.</p>
        <button class="btn install" popovertarget="instalar" popovertargetaction="hide">Entendido</button>
        </div>
        \(days.last.map { renderNow($0, lastChange: lastChange) } ?? "")
        <section class="history" aria-labelledby="history-title">
        <h2 id="history-title">Registro histórico</h2>
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
                if let horario = park.horario, park.endCode >= 3 {
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
