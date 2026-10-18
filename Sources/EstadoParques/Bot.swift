import Foundation

/// One run of the bot: fetch, compare, save, post. Every outside dependency is injected, so tests can
/// replace the city API, Mastodon, the files and the clock.
struct Bot {
    struct Paths {
        var state = "estado_parques.json"
        var history = "estadisticas_parques.ndjson"
        var apiStatus = "estado_api.json"
    }

    static let outageText = "⚠️ El servicio oficial de datos del Ayuntamiento de Madrid no está disponible "
        + "temporalmente. No se puede consultar el estado de los parques; se avisará cuando vuelva a funcionar."

    /// Posts only reach Mastodon in production; elsewhere they are printed
    var isProduction: Bool
    var paths = Paths()
    var fetchParks: () async throws -> [String: ParkAttributes] = MadridAPI.fetchParkAlerts
    var post: (String) async throws -> Void = MastodonPoster.post(text:)
    var now: () -> Date = Date.init

    /// Throws only for unexpected failures; an unreachable city API is handled by announcing the outage once
    func run() async throws {
        let currentData: [String: ParkAttributes]
        do {
            currentData = try await fetchParks()
        } catch let error as MadridAPIError {
            print("⚠️ \(error)")
            try await announceOutage()
            return
        }

        let wasAPIDown = StateManager.loadAPIDown(from: paths.apiStatus)
        if wasAPIDown {
            try StateManager.saveAPIDown(false, to: paths.apiStatus)
            print("✅ Servicio oficial recuperado; se publica el estado actual de los parques")
        }

        let previousData = StateManager.loadPreviousState(from: paths.state)
        let currentState = currentData.mapValues {
            ParkState(code: $0.alertaDescripcion, horario: $0.horarioIncidencia, fecha: $0.fechaIncidencia)
        }
        let (changedParks, changeEvents) = ChangeDetector.detect(
            previous: previousData,
            current: currentState,
            detectedAt: ISO8601DateFormatter().string(from: now())
        )

        let statusText = StatusFormatter.formatStatus(current: currentData, now: now())
        print(statusText)

        // Saved on any difference, the schedule date included, so the website shows current dates
        if currentState != previousData {
            try StateManager.saveState(currentState, to: paths.state)
        }
        if !changedParks.isEmpty {
            try StateManager.appendStatistics(changeEvents, to: paths.history)
        }

        if !changedParks.isEmpty || wasAPIDown {
            if isProduction {
                try await post(statusText)
            }
        } else {
            print("ℹ️ Sin cambios detectados")
        }
    }

    private func announceOutage() async throws {
        if StateManager.loadAPIDown(from: paths.apiStatus) {
            print("ℹ️ Caída del servicio ya notificada anteriormente")
            return
        }
        try StateManager.saveAPIDown(true, to: paths.apiStatus)
        print(Self.outageText)
        if isProduction {
            try await post(Self.outageText)
        }
    }
}
