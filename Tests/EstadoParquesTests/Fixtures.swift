import Foundation
@testable import EstadoParques

enum Fixtures {
    /// The nine parks the city reports, as the API names them
    static let parkNames = [
        "Jardines del Buen Retiro",
        "Jardín del Capricho de la Alameda de Osuna",
        "Parque Juan Carlos I",
        "Parque Juan Pablo II",
        "Parque Lineal del Manzanares",
        "Parque Quinta Fuente del Berro",
        "Parque Quinta de Torre Arias",
        "Parque Quinta de los Molinos",
        "Rosaleda del Parque del Oeste",
    ]

    /// Sunday 18 October 2026, 16:27 UTC: 18:27 in Madrid (summer time)
    static let sundayEvening = date("2026-10-18T16:27:00Z")

    static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    static func park(
        _ name: String,
        code: Int,
        horario: String? = nil,
        fecha: String? = "18/10/2026"
    ) -> ParkAttributes {
        ParkAttributes(
            zonaVerde: name,
            alertaDescripcion: code,
            fechaIncidencia: fecha,
            horarioIncidencia: horario,
            previsionApertura: nil,
            observaciones: nil,
            objectId: 1
        )
    }

    /// Every park open except the given alerts
    static func parks(alerts: [String: (code: Int, horario: String?)] = [:]) -> [String: ParkAttributes] {
        Dictionary(uniqueKeysWithValues: parkNames.map { name in
            let alert = alerts[name]
            return (name, park(name, code: alert?.code ?? 1, horario: alert?.horario))
        })
    }

    /// A fresh empty directory for one test's files
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EstadoParquesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// Post length as Mastodon counts it: Unicode code points, with every link counted as 23 characters
func mastodonLength(_ text: String) -> Int {
    let links = try! NSRegularExpression(pattern: "https?://\\S+")
    let range = NSRange(text.startIndex..., in: text)
    let counted = links.stringByReplacingMatches(in: text, range: range, withTemplate: String(repeating: "x", count: 23))
    return counted.unicodeScalars.count
}

let mastodonLimit = 500
