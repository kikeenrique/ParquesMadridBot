import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let isProduction = ProcessInfo.processInfo.environment["PRODUCTION"]?.lowercased() == "true"
print("🔍 Iniciando bot. Modo producción: \(isProduction)")

do {
    let currentData = try await MadridAPI.fetchParkAlerts()
    let previousData = StateManager.loadPreviousState(from: "estado_parques.json")

    var changedParks: Set<String> = []
    var changeEvents: [ChangeEvent] = []
    let now = ISO8601DateFormatter().string(from: Date())

    for (park, currentCode) in currentData {
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

    let statusText = StatusFormatter.formatStatus(current: currentData, changes: changedParks)
    print(statusText)

    if !changedParks.isEmpty {
        try StateManager.saveState(currentData, to: "estado_parques.json")
        try StateManager.appendStatistics(changeEvents, to: "estadisticas_parques.ndjson")

        if isProduction {
            try await MastodonPoster.post(text: statusText)
        }
    } else {
        print("ℹ️ Sin cambios detectados")
    }
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
