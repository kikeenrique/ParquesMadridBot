import Foundation
import Testing
@testable import EstadoParques

struct ParkMapTests {
    static let cardIDs = ["Jardines del Buen Retiro": "c-retiro", "Parque Juan Carlos I": "c-juan-carlos-i"]

    @Test("Every park the city reports has a place on the map")
    func everyParkHasASpot() {
        let codes = Dictionary(uniqueKeysWithValues: Fixtures.parkNames.map { ($0, 1) })
        let map = ParkMap.render(codes: codes, cardIDs: [:])
        #expect(map.components(separatedBy: "<circle").count - 1 == Fixtures.parkNames.count)
    }

    @Test("Each dot has its level's colour, and links to the park's card")
    func dotsLinkToCards() {
        let map = ParkMap.render(codes: ["Jardines del Buen Retiro": 4, "Parque Juan Carlos I": 1], cardIDs: Self.cardIDs)
        #expect(map.contains(##"<a href="#c-retiro" aria-label="Retiro: alerta naranja">"##))
        #expect(map.contains(#"<title>Retiro: alerta naranja</title><circle class="l4""#))
        #expect(map.contains(##"<a href="#c-juan-carlos-i" aria-label="Juan Carlos I: abierto">"##))
    }

    @Test("The most severe dot is drawn last, on top where dots touch")
    func severeOnTop() throws {
        let map = ParkMap.render(codes: [
            "Parque Quinta de los Molinos": 5, "Parque Quinta de Torre Arias": 3, "Parque Juan Pablo II": 1,
        ], cardIDs: [:])
        let order = try ["Juan Pablo II:", "Torre Arias:", "Quinta de los Molinos:"].map {
            try #require(map.range(of: $0)?.lowerBound)
        }
        #expect(order == order.sorted())
    }

    @Test("A park without a card gets a dot without a link; an unknown park gets no dot")
    func missingCardOrPlace() {
        let map = ParkMap.render(codes: ["Parque Juan Pablo II": 3, "Parque Nuevo": 4], cardIDs: Self.cardIDs)
        #expect(map.contains("<g><title>Juan Pablo II: alerta amarilla</title>"))
        #expect(map.contains("<a href") == false)
        #expect(map.contains("Nuevo") == false)
    }

    @Test func captionUnderTheMap() {
        let map = ParkMap.render(codes: [:], cardIDs: [:])
        #expect(map.contains("</svg>\n<figcaption>Localizaciones en el mapa de Madrid</figcaption>"))
    }
}
