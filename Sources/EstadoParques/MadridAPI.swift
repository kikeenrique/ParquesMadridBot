import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum MadridAPI {
    static let url = URL(string: "https://sigma.madrid.es/hosted/rest/services/MEDIO_AMBIENTE/ALERTAS_PARQUES/MapServer/0/query?f=json&where=1%3D1&outFields=*&returnGeometry=false")!

    static func fetchParkAlerts() async throws -> [String: Int] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, _): (Data, URLResponse) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIResponse.self, from: data)

        var parks: [String: Int] = [:]
        for feature in response.features {
            let name = feature.attributes.zonaVerde.trimmingCharacters(in: CharacterSet.whitespaces)
            let code = feature.attributes.alertaDescripcion
            parks[name] = code
        }
        return parks
    }
}
