import Foundation
import Testing
@testable import EstadoParques

struct MadridAPITests {
    @Test func parsesParksByName() throws {
        let body = """
        {"features":[
          {"attributes":{"ZONA_VERDE":"Jardines del Buen Retiro ","ALERTA_DESCRIPCION":3,
            "FECHA_INCIDENCIA":"18/10/2026","HORARIO_INCIDENCIA":"De 18:00 h a 09:00 h",
            "PREVISION_APERTURA":null,"OBSERVACIONES":null,"OBJECTID":1}},
          {"attributes":{"ZONA_VERDE":"Parque Juan Carlos I","ALERTA_DESCRIPCION":1,
            "FECHA_INCIDENCIA":"18/10/2026","HORARIO_INCIDENCIA":null,
            "PREVISION_APERTURA":null,"OBSERVACIONES":null,"OBJECTID":5}}
        ]}
        """
        let parks = try MadridAPI.parse(Data(body.utf8))

        #expect(parks.keys.sorted() == ["Jardines del Buen Retiro", "Parque Juan Carlos I"], "names are trimmed")
        let retiro = try #require(parks["Jardines del Buen Retiro"])
        #expect(retiro.alertaDescripcion == 3)
        #expect(retiro.horarioIncidencia == "De 18:00 h a 09:00 h")
        #expect(retiro.fechaIncidencia == "18/10/2026")
        #expect(parks["Parque Juan Carlos I"]?.horarioIncidencia == nil)
    }

    @Test("ArcGIS failures arrive as a 200 with an error envelope")
    func errorEnvelopeMeansServiceUnavailable() {
        let body = #"{"error":{"code":500,"message":"Error performing query operation","details":[]}}"#
        expectServiceUnavailable(detailContaining: "código 500, Error performing query operation") {
            try MadridAPI.parse(Data(body.utf8))
        }
    }

    @Test func unexpectedBodyMeansServiceUnavailable() {
        expectServiceUnavailable(detailContaining: "respuesta inesperada") {
            try MadridAPI.parse(Data("<html>Mantenimiento</html>".utf8))
        }
    }

    private func expectServiceUnavailable(
        detailContaining expected: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: () throws -> Any
    ) {
        do {
            _ = try body()
            Issue.record("Expected MadridAPIError.serviceUnavailable", sourceLocation: sourceLocation)
        } catch MadridAPIError.serviceUnavailable(let detail) {
            #expect(detail.contains(expected), "detail was: \(detail)", sourceLocation: sourceLocation)
        } catch {
            Issue.record("Wrong error thrown: \(error)", sourceLocation: sourceLocation)
        }
    }
}
