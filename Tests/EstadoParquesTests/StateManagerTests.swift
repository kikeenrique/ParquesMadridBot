import Foundation
import Testing
@testable import EstadoParques

struct StateManagerTests {
    let directory: URL

    init() throws {
        directory = try Fixtures.temporaryDirectory()
    }

    private func path(_ name: String) -> String {
        directory.appendingPathComponent(name).path
    }

    private func write(_ text: String, to name: String) throws {
        try text.write(toFile: path(name), atomically: true, encoding: .utf8)
    }

    // MARK: - Park state

    @Test func stateSurvivesARoundTrip() throws {
        let state = [
            "Jardines del Buen Retiro": ParkState(code: 3, horario: "De 18:00 h a 09:00 h", fecha: "18/10/2026"),
            "Parque Juan Carlos I": ParkState(code: 1, horario: nil, fecha: "18/10/2026"),
        ]
        try StateManager.saveState(state, to: path("estado.json"))
        #expect(StateManager.loadPreviousState(from: path("estado.json")) == state)
    }

    @Test("The legacy format (alert code only) still loads")
    func legacyStateLoads() throws {
        try write(#"{ "Jardines del Buen Retiro": 4, "Parque Juan Carlos I": 1 }"#, to: "estado.json")
        let state = StateManager.loadPreviousState(from: path("estado.json"))
        #expect(state["Jardines del Buen Retiro"] == ParkState(code: 4, horario: nil))
        #expect(state["Parque Juan Carlos I"] == ParkState(code: 1, horario: nil))
    }

    @Test("State saved before the schedule date was tracked still loads")
    func stateWithoutDateLoads() throws {
        try write(#"{ "Jardines del Buen Retiro": { "code": 4, "horario": "De 00:00 h a 18:00 h" } }"#, to: "estado.json")
        let state = StateManager.loadPreviousState(from: path("estado.json"))
        #expect(state["Jardines del Buen Retiro"] == ParkState(code: 4, horario: "De 00:00 h a 18:00 h", fecha: nil))
    }

    @Test(arguments: [nil, "not json"])
    func missingOrUnreadableStateIsEmpty(contents: String?) throws {
        if let contents {
            try write(contents, to: "estado.json")
        }
        #expect(StateManager.loadPreviousState(from: path("estado.json")).isEmpty)
    }

    // MARK: - Change log

    @Test func changeLogAppendsOneLinePerEvent() throws {
        let first = ChangeEvent(
            detectedAt: "2026-10-18T16:27:04Z", parque: "Jardines del Buen Retiro",
            fromCode: 4, toCode: 3, fromOpen: true, toOpen: true,
            fromHorario: "De 00:00 h a 18:00 h", toHorario: "De 18:00 h a 09:00 h"
        )
        let second = ChangeEvent(
            detectedAt: "2026-10-19T07:00:00Z", parque: "Jardines del Buen Retiro",
            fromCode: 3, toCode: 1, fromOpen: true, toOpen: true,
            fromHorario: "De 18:00 h a 09:00 h", toHorario: nil
        )
        try StateManager.appendStatistics([first], to: path("log.ndjson"))
        try StateManager.appendStatistics([second], to: path("log.ndjson"))

        let lines = try String(contentsOfFile: path("log.ndjson"), encoding: .utf8).split(separator: "\n")
        try #require(lines.count == 2)
        let decoded = try lines.map { try JSONDecoder().decode(ChangeEvent.self, from: Data($0.utf8)) }
        #expect(decoded.map(\.toCode) == [3, 1])
        #expect(lines[1].contains("to_horario") == false, "an absent schedule is left out, not written as null")
    }

    @Test("Events logged before schedules were tracked still decode")
    func legacyEventDecodes() throws {
        let line = #"{"detected_at":"2026-03-14T08:39:05Z","from_code":3,"from_open":true,"parque":"Rosaleda del Parque del Oeste","to_code":4,"to_open":true}"#
        let event = try JSONDecoder().decode(ChangeEvent.self, from: Data(line.utf8))
        #expect(event.toCode == 4)
        #expect(event.fromHorario == nil)
        #expect(event.toHorario == nil)
    }

    @Test func emptyEventListWritesNothing() throws {
        try StateManager.appendStatistics([], to: path("log.ndjson"))
        #expect(FileManager.default.fileExists(atPath: path("log.ndjson")) == false)
    }

    // MARK: - API outage flag

    @Test func outageFlagRoundTrips() throws {
        #expect(StateManager.loadAPIDown(from: path("api.json")) == false, "no file means the API is up")
        try StateManager.saveAPIDown(true, to: path("api.json"))
        #expect(StateManager.loadAPIDown(from: path("api.json")))
        try StateManager.saveAPIDown(false, to: path("api.json"))
        #expect(StateManager.loadAPIDown(from: path("api.json")) == false)
    }
}
