import Testing
@testable import EstadoParques

struct ChangeDetectorTests {
    let detectedAt = "2026-10-18T16:27:04Z"

    @Test func identicalStateIsNoChange() {
        let state = ["Jardines del Buen Retiro": ParkState(code: 3, horario: "De 18:00 h a 09:00 h", fecha: "18/10/2026")]
        let result = ChangeDetector.detect(previous: state, current: state, detectedAt: detectedAt)
        #expect(result.changedParks.isEmpty)
        #expect(result.events.isEmpty)
    }

    @Test("A new schedule date alone is not a change: it moves every day")
    func dateOnlyIsNoChange() {
        let result = ChangeDetector.detect(
            previous: ["Parque Juan Carlos I": ParkState(code: 1, horario: nil, fecha: "17/10/2026")],
            current: ["Parque Juan Carlos I": ParkState(code: 1, horario: nil, fecha: "18/10/2026")],
            detectedAt: detectedAt
        )
        #expect(result.changedParks.isEmpty)
        #expect(result.events.isEmpty)
    }

    @Test func levelChangeIsLogged() throws {
        let result = ChangeDetector.detect(
            previous: ["Jardines del Buen Retiro": ParkState(code: 4, horario: "De 00:00 h a 18:00 h")],
            current: ["Jardines del Buen Retiro": ParkState(code: 5, horario: "De 00:00 h a 24:00 h")],
            detectedAt: detectedAt
        )
        #expect(result.changedParks == ["Jardines del Buen Retiro"])
        let event = try #require(result.events.first)
        #expect(event.detectedAt == detectedAt)
        #expect(event.fromCode == 4)
        #expect(event.toCode == 5)
        #expect(event.fromOpen == true)
        #expect(event.toOpen == false)
    }

    @Test("A change of hours alone is a change, logged with both schedules")
    func scheduleOnlyChangeIsLogged() throws {
        let result = ChangeDetector.detect(
            previous: ["Jardines del Buen Retiro": ParkState(code: 4, horario: "De 21:00 h a 24:00 h")],
            current: ["Jardines del Buen Retiro": ParkState(code: 4, horario: "De 00:00 h a 18:00 h")],
            detectedAt: detectedAt
        )
        #expect(result.changedParks == ["Jardines del Buen Retiro"])
        let event = try #require(result.events.first)
        #expect(event.fromCode == event.toCode)
        #expect(event.fromHorario == "De 21:00 h a 24:00 h")
        #expect(event.toHorario == "De 00:00 h a 18:00 h")
    }

    @Test("A park seen for the first time is posted, but has nothing to log")
    func newParkIsChangedWithoutEvent() {
        let result = ChangeDetector.detect(
            previous: [:],
            current: ["Parque Juan Pablo II": ParkState(code: 1, horario: nil)],
            detectedAt: detectedAt
        )
        #expect(result.changedParks == ["Parque Juan Pablo II"])
        #expect(result.events.isEmpty)
    }

    @Test func onlyChangedParksAreReported() {
        let result = ChangeDetector.detect(
            previous: [
                "Parque Juan Carlos I": ParkState(code: 1, horario: nil),
                "Parque Quinta de los Molinos": ParkState(code: 3, horario: "De 18:00 h a 09:00 h"),
            ],
            current: [
                "Parque Juan Carlos I": ParkState(code: 1, horario: nil),
                "Parque Quinta de los Molinos": ParkState(code: 1, horario: nil),
            ],
            detectedAt: detectedAt
        )
        #expect(result.changedParks == ["Parque Quinta de los Molinos"])
        #expect(result.events.map(\.parque) == ["Parque Quinta de los Molinos"])
    }
}
