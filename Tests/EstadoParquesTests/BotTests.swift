import Foundation
import Testing
@testable import EstadoParques

struct BotTests {
    /// Collects what the bot would have sent to Mastodon
    final class Outbox {
        var posts: [String] = []
    }

    struct Boom: Error, Equatable {}

    let directory: URL
    let paths: Bot.Paths

    init() throws {
        directory = try Fixtures.temporaryDirectory()
        paths = Bot.Paths(
            state: directory.appendingPathComponent("estado.json").path,
            history: directory.appendingPathComponent("log.ndjson").path,
            apiStatus: directory.appendingPathComponent("api.json").path
        )
    }

    private func bot(
        parks: [String: ParkAttributes]? = nil,
        failure: Error? = nil,
        production: Bool = true,
        outbox: Outbox
    ) -> Bot {
        Bot(
            isProduction: production,
            paths: paths,
            fetchParks: {
                if let failure { throw failure }
                return parks ?? Fixtures.parks()
            },
            post: { outbox.posts.append($0) },
            now: { Fixtures.sundayEvening }
        )
    }

    private func savedState() -> [String: ParkState] {
        StateManager.loadPreviousState(from: paths.state)
    }

    private func loggedEvents() throws -> [ChangeEvent] {
        guard FileManager.default.fileExists(atPath: paths.history) else { return [] }
        return try String(contentsOfFile: paths.history, encoding: .utf8)
            .split(separator: "\n")
            .map { try JSONDecoder().decode(ChangeEvent.self, from: Data($0.utf8)) }
    }

    private static let yellowRetiro: [String: (code: Int, horario: String?)] = [
        "Jardines del Buen Retiro": (3, "De 18:00 h a 09:00 h"),
    ]

    // MARK: - Normal runs

    @Test("The first run posts every park and saves the state, with nothing to log yet")
    func firstRun() async throws {
        let outbox = Outbox()
        try await bot(outbox: outbox).run()

        #expect(outbox.posts.count == 1)
        #expect(outbox.posts.first?.contains("Parques de Madrid, 2026-10-18 dom a las 18:27") == true)
        #expect(savedState().count == Fixtures.parkNames.count)
        #expect(try loggedEvents().isEmpty)
    }

    @Test func unchangedParksPostNothing() async throws {
        let outbox = Outbox()
        try await bot(outbox: outbox).run()
        try await bot(outbox: outbox).run()
        #expect(outbox.posts.count == 1, "only the first run posts")
    }

    @Test func alertChangeIsPostedAndLogged() async throws {
        let outbox = Outbox()
        try await bot(outbox: outbox).run()
        try await bot(parks: Fixtures.parks(alerts: Self.yellowRetiro), outbox: outbox).run()

        #expect(outbox.posts.count == 2)
        #expect(outbox.posts.last?.contains("🟡 Alerta amarilla\n· Jardines del Buen Retiro ⏰ 18:00–09:00") == true)
        let events = try loggedEvents()
        #expect(events.map(\.parque) == ["Jardines del Buen Retiro"])
        #expect(savedState()["Jardines del Buen Retiro"]?.code == 3)
    }

    @Test("A new schedule date is saved for the website, but not posted or logged")
    func dateOnlyChangeIsSavedSilently() async throws {
        let outbox = Outbox()
        try await bot(outbox: outbox).run()

        var nextDay = Fixtures.parks()
        for name in Fixtures.parkNames {
            nextDay[name] = Fixtures.park(name, code: 1, fecha: "19/10/2026")
        }
        try await bot(parks: nextDay, outbox: outbox).run()

        #expect(outbox.posts.count == 1)
        #expect(try loggedEvents().isEmpty)
        #expect(savedState()["Parque Juan Carlos I"]?.fecha == "19/10/2026")
    }

    @Test("Outside production nothing reaches Mastodon, but state is still saved")
    func notProductionPostsNothing() async throws {
        let outbox = Outbox()
        try await bot(parks: Fixtures.parks(alerts: Self.yellowRetiro), production: false, outbox: outbox).run()
        #expect(outbox.posts.isEmpty)
        #expect(savedState()["Jardines del Buen Retiro"]?.code == 3)
    }

    // MARK: - City API outages

    @Test("An outage is announced once, however many runs it lasts")
    func outageIsAnnouncedOnce() async throws {
        let outbox = Outbox()
        let down = MadridAPIError.serviceUnavailable(detail: "fallo de red")
        try await bot(failure: down, outbox: outbox).run()
        try await bot(failure: down, outbox: outbox).run()

        #expect(outbox.posts == [Bot.outageText])
        #expect(StateManager.loadAPIDown(from: paths.apiStatus))
    }

    @Test("When the API comes back, the current state is posted even if no park changed")
    func recoveryPostsCurrentState() async throws {
        let outbox = Outbox()
        try await bot(outbox: outbox).run()
        try await bot(failure: MadridAPIError.serviceUnavailable(detail: "código 500"), outbox: outbox).run()
        try await bot(outbox: outbox).run()

        #expect(outbox.posts.count == 3)
        #expect(outbox.posts.last?.hasPrefix("Parques de Madrid, ") == true)
        #expect(StateManager.loadAPIDown(from: paths.apiStatus) == false)
    }

    @Test("Outside production an outage is recorded but not posted")
    func outageOutsideProduction() async throws {
        let outbox = Outbox()
        try await bot(failure: MadridAPIError.serviceUnavailable(detail: "x"), production: false, outbox: outbox).run()
        #expect(outbox.posts.isEmpty)
        #expect(StateManager.loadAPIDown(from: paths.apiStatus))
    }

    // MARK: - Unexpected failures

    @Test("Unexpected errors fail the run, without posting or flagging an outage")
    func unexpectedErrorFailsTheRun() async throws {
        let outbox = Outbox()
        await #expect(throws: Boom()) {
            try await bot(failure: Boom(), outbox: outbox).run()
        }
        #expect(outbox.posts.isEmpty)
        #expect(StateManager.loadAPIDown(from: paths.apiStatus) == false)
    }

    @Test("A failed post fails the run, so CI does not commit the state and the next run posts again")
    func failedPostFailsTheRun() async throws {
        let failing = Bot(
            isProduction: true,
            paths: paths,
            fetchParks: { Fixtures.parks() },
            post: { _ in throw Boom() },
            now: { Fixtures.sundayEvening }
        )
        await #expect(throws: Boom()) {
            try await failing.run()
        }
    }
}
