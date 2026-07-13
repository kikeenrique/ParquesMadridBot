import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum MadridAPIError: Error, CustomStringConvertible {
    case serviceUnavailable(detail: String)

    var description: String {
        switch self {
        case .serviceUnavailable(let detail):
            return "El servicio oficial no está disponible: \(detail)"
        }
    }
}

enum MadridAPI {
    static let url = URL(string: "https://sigma.madrid.es/hosted/rest/services/MEDIO_AMBIENTE/ALERTAS_PARQUES/MapServer/0/query?f=json&where=1%3D1&outFields=*&returnGeometry=false")!

    static func fetchParkAlerts() async throws -> [String: ParkAttributes] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, _): (Data, URLResponse) = try await URLSession.shared.data(for: request)

        let response: APIResponse
        do {
            response = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            // ArcGIS reports failures as a 200 with an error envelope instead of "features"
            if let envelope = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw MadridAPIError.serviceUnavailable(detail: "código \(envelope.error.code), \(envelope.error.message)")
            }
            throw MadridAPIError.serviceUnavailable(detail: "respuesta inesperada (\(error))")
        }

        var parks: [String: ParkAttributes] = [:]
        for feature in response.features {
            let name = feature.attributes.zonaVerde.trimmingCharacters(in: CharacterSet.whitespaces)
            parks[name] = feature.attributes
        }
        return parks
    }
}
