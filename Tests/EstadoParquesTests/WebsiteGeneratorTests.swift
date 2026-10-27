import Foundation
import Testing
@testable import EstadoParques

struct WebsiteGeneratorTests {
    // MARK: - Hours and dates

    @Test(arguments: [
        ("De 00:00 h a 18:00 h", "00:00–18:00"),
        ("De 21:00 h a 24:00 h", "21:00–24:00"),
        ("Todo el día", "Todo el día"),  // not two times: shown as given
    ])
    func compactSchedule(horario: String, expected: String) {
        #expect(WebsiteGenerator.compactSchedule(horario) == expected)
    }

    @Test("Hours that end at or before they start run into the next day")
    func overnightHoursSpanTwoDays() {
        #expect(WebsiteGenerator.scheduleWithDays("De 18:00 h a 09:00 h", fecha: "18/10/2026")
            == ["Dom 18, 18:00", "lun 19, 09:00"])
    }

    @Test func overnightHoursCrossTheMonthEnd() {
        #expect(WebsiteGenerator.scheduleWithDays("De 18:00 h a 09:00 h", fecha: "31/10/2026")
            == ["Sáb 31, 18:00", "dom 1, 09:00"])
    }

    @Test(arguments: [
        ("De 09:00 h a 18:00 h", "Dom 18, 09:00–18:00"),
        ("De 21:00 h a 24:00 h", "Dom 18, 21:00–24:00"),  // 24:00 closes the same day
    ])
    func sameDayHours(horario: String, expected: String) {
        #expect(WebsiteGenerator.scheduleWithDays(horario, fecha: "18/10/2026") == [expected])
    }

    @Test("Without a usable date, the bare hours are shown", arguments: [nil, "", "pronto"])
    func missingDateFallsBack(fecha: String?) {
        #expect(WebsiteGenerator.scheduleWithDays("De 18:00 h a 09:00 h", fecha: fecha) == ["18:00–09:00"])
    }

    // MARK: - Generated page

    /// Three days of history: Retiro goes yellow on Friday and orange on Saturday evening;
    /// Juan Carlos I moves between two codes that both read "abierto"
    struct GeneratedPage {
        let html: String

        init() throws {
            let directory = try Fixtures.temporaryDirectory()
            let state: [String: ParkState] = [
                "Jardines del Buen Retiro": ParkState(code: 4, horario: "De 21:00 h a 24:00 h", fecha: "18/10/2026"),
                "Parque Juan Carlos I": ParkState(code: 2, horario: nil, fecha: "18/10/2026"),
                "Parque Quinta de los Molinos": ParkState(code: 1, horario: nil, fecha: "18/10/2026"),
            ]
            let statePath = directory.appendingPathComponent("estado.json").path
            try StateManager.saveState(state, to: statePath)

            let historyPath = directory.appendingPathComponent("log.ndjson").path
            try StateManager.appendStatistics([
                ChangeEvent(detectedAt: "2026-10-16T10:00:00Z", parque: "Jardines del Buen Retiro",
                            fromCode: 1, toCode: 3, fromOpen: true, toOpen: true,
                            fromHorario: nil, toHorario: "De 18:00 h a 09:00 h"),
                ChangeEvent(detectedAt: "2026-10-17T05:00:00Z", parque: "Parque Juan Carlos I",
                            fromCode: 1, toCode: 2, fromOpen: true, toOpen: true,
                            fromHorario: nil, toHorario: nil),
                ChangeEvent(detectedAt: "2026-10-17T19:03:56Z", parque: "Jardines del Buen Retiro",
                            fromCode: 3, toCode: 4, fromOpen: true, toOpen: true,
                            fromHorario: "De 18:00 h a 09:00 h", toHorario: "De 21:00 h a 24:00 h"),
            ], to: historyPath)

            try WebsiteGenerator.generate(
                into: directory.path, statePath: statePath, historyPath: historyPath, now: Fixtures.sundayEvening
            )
            html = try String(contentsOf: directory.appendingPathComponent("index.html"), encoding: .utf8)
        }

        /// The markup of one day's timeline entry and panel
        func day(_ id: String) throws -> Substring {
            let start = try #require(html.range(of: "id=\"d-\(id)\""))
            let end = html.range(of: "<input", range: start.upperBound..<html.endIndex)?.lowerBound ?? html.endIndex
            return html[start.lowerBound..<end]
        }
    }

    @Test("One day per date from the first logged change to today, today selected")
    func oneEntryPerDay() throws {
        let page = try GeneratedPage()
        #expect(page.html.components(separatedBy: "type=\"radio\"").count - 1 == 3)
        #expect(page.html.contains(#"id="d-2026-10-18" checked"#))
        #expect(page.html.contains(#"id="d-2026-10-17" checked"#) == false)
    }

    @Test func todayCardsShowLevelAndDatedHours() throws {
        let page = try GeneratedPage()
        #expect(page.html.contains(#"<span class="chip l4">1 en alerta naranja</span>"#))
        #expect(page.html.contains(#"<span class="chip l1">2 abiertos</span>"#))
        #expect(page.html.contains(#"<span class="when"><span>Dom 18, 21:00–24:00</span></span>"#))
        #expect(page.html.contains(#"<span class="when"><span>Sin alertas</span></span>"#))
    }

    @Test("The note under \"Ahora\" gives the last change in Madrid time")
    func lastChangeNote() throws {
        let page = try GeneratedPage()
        #expect(page.html.contains("Sin cambios desde el sábado 17 de octubre, a las 21:03."))
    }

    @Test("Past days show the hours and changes logged for them")
    func pastDayFromHistory() throws {
        let saturday = try GeneratedPage().day("2026-10-17")
        #expect(saturday.contains(#"Jardines del Buen Retiro <span class="horario">21:00–24:00</span>"#))
        #expect(saturday.contains("alerta amarilla → alerta naranja (21:03)"))
    }

    @Test("Changes between codes that read the same are not listed")
    func invisibleChangesAreHidden() throws {
        let saturday = try GeneratedPage().day("2026-10-17")
        #expect(saturday.contains("abierto → abierto") == false)
    }

    @Test("The AI-generated park pictures and their licence are credited once, under the cards")
    func pictureLicenceUnderTheCards() throws {
        let html = try GeneratedPage().html
        let credit = #"resources/parks/LICENSE.md" rel="license">CC BY-SA 4.0</a>"#
        #expect(html.components(separatedBy: credit).count - 1 == 1)
        let cardsEnd = try #require(html.range(of: "</ul>\n<p class=\"credit\">Ilustraciones generadas con IA"))
        let history = try #require(html.range(of: "class=\"history\""))
        #expect(cardsEnd.lowerBound < history.lowerBound)
    }

    @Test func friday() throws {
        let friday = try GeneratedPage().day("2026-10-16")
        #expect(friday.contains(#"Jardines del Buen Retiro <span class="horario">18:00–09:00</span>"#))
        #expect(friday.contains("abierto → alerta amarilla (12:00)"))
    }
}
