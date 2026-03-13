import Foundation

// MARK: - Madrid API Response

struct APIResponse: Codable {
    let features: [Feature]
}

struct Feature: Codable {
    let attributes: ParkAttributes
}

struct ParkAttributes: Codable {
    let zonaVerde: String
    let alertaDescripcion: Int
    let fechaIncidencia: String?
    let horarioIncidencia: String?
    let previsionApertura: Int?
    let observaciones: String?
    let objectId: Int

    enum CodingKeys: String, CodingKey {
        case zonaVerde = "ZONA_VERDE"
        case alertaDescripcion = "ALERTA_DESCRIPCION"
        case fechaIncidencia = "FECHA_INCIDENCIA"
        case horarioIncidencia = "HORARIO_INCIDENCIA"
        case previsionApertura = "PREVISION_APERTURA"
        case observaciones = "OBSERVACIONES"
        case objectId = "OBJECTID"
    }
}

// MARK: - Statistics

struct ChangeEvent: Codable {
    let detectedAt: String
    let parque: String
    let fromCode: Int
    let toCode: Int
    let fromOpen: Bool
    let toOpen: Bool

    enum CodingKeys: String, CodingKey {
        case detectedAt = "detected_at"
        case parque
        case fromCode = "from_code"
        case toCode = "to_code"
        case fromOpen = "from_open"
        case toOpen = "to_open"
    }
}
