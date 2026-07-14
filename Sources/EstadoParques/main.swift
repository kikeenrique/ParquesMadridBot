import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let isProduction = ProcessInfo.processInfo.environment["PRODUCTION"]?.lowercased() == "true"
print("🔍 Iniciando bot. Modo producción: \(isProduction)")

let apiStatusPath = "estado_api.json"

do {
    let currentData = try await MadridAPI.fetchParkAlerts()

    let wasAPIDown = StateManager.loadAPIDown(from: apiStatusPath)
    if wasAPIDown {
        try StateManager.saveAPIDown(false, to: apiStatusPath)
        print("✅ Servicio oficial recuperado; se publica el estado actual de los parques")
    }

    let previousData = StateManager.loadPreviousState(from: "estado_parques.json")

    var changedParks: Set<String> = []
    var changeEvents: [ChangeEvent] = []
    let now = ISO8601DateFormatter().string(from: Date())

    let currentState = currentData.mapValues { $0.alertaDescripcion }

    for (park, attrs) in currentData {
        let currentCode = attrs.alertaDescripcion
        if let previousCode = previousData[park] {
            if previousCode != currentCode {
                changedParks.insert(park)
                changeEvents.append(ChangeEvent(
                    detectedAt: now,
                    parque: park,
                    fromCode: previousCode,
                    toCode: currentCode,
                    fromOpen: StatusFormatter.isOpen(previousCode),
                    toOpen: StatusFormatter.isOpen(currentCode)
                ))
            }
        } else {
            changedParks.insert(park)
        }
    }

    let statusText = StatusFormatter.formatStatus(current: currentData)
    print(statusText)

    if !changedParks.isEmpty {
        try StateManager.saveState(currentState, to: "estado_parques.json")
        try StateManager.appendStatistics(changeEvents, to: "estadisticas_parques.ndjson")
    }

    if !changedParks.isEmpty || wasAPIDown {
        if isProduction {
            try await MastodonPoster.post(text: statusText)
        }
    } else {
        print("ℹ️ Sin cambios detectados")
    }
} catch let error as MadridAPIError {
    print("⚠️ \(error)")

    if StateManager.loadAPIDown(from: apiStatusPath) {
        print("ℹ️ Caída del servicio ya notificada anteriormente")
    } else {
        do {
            try StateManager.saveAPIDown(true, to: apiStatusPath)
            let outageText = "⚠️ El servicio oficial de datos del Ayuntamiento de Madrid no está disponible temporalmente. No se puede consultar el estado de los parques; se avisará cuando vuelva a funcionar."
            print(outageText)
            if isProduction {
                try await MastodonPoster.post(text: outageText)
            }
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
