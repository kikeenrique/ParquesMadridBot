import Foundation
import Testing
@testable import EstadoParques

struct StatusFormatterTests {
    @Test("Post time is Madrid local time, not the runner's UTC", arguments: [
        ("2026-10-18T16:27:00Z", "Parques de Madrid, 2026-10-18 dom a las 18:27\n"),  // summer time, UTC+2
        ("2026-12-01T10:00:00Z", "Parques de Madrid, 2026-12-01 mar a las 11:00\n"),  // winter time, UTC+1
        ("2026-10-18T22:30:00Z", "Parques de Madrid, 2026-10-19 lun a las 00:30\n"),  // already Monday in Madrid
    ])
    func madridTime(utc: String, expected: String) {
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(), now: Fixtures.date(utc))
        #expect(post.hasPrefix(expected))
    }

    @Test("Alerts come first, most severe last, then the open parks")
    func groupOrder() throws {
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(alerts: [
            "Jardines del Buen Retiro": (5, "De 00:00 h a 24:00 h"),
            "Parque Quinta de los Molinos": (4, "De 10:00 h a 20:00 h"),
            "Parque Quinta de Torre Arias": (3, "De 18:00 h a 09:00 h"),
        ]), now: Fixtures.sundayEvening)

        let headers = ["🟡 Alerta amarilla\n", "🟠 Alerta naranja\n", "🔴 Cerrados\n", "🟢 Abiertos\n"]
        let positions = try headers.map { try #require(post.range(of: $0)?.lowerBound, "missing \($0)") }
        #expect(positions == positions.sorted())
    }

    @Test("Every alert level shows its hours on the park's line; open parks show none", arguments: [3, 4, 5])
    func alertLevelsShowHours(code: Int) {
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(alerts: [
            "Jardines del Buen Retiro": (code, "De 18:00 h a 09:00 h"),
        ]), now: Fixtures.sundayEvening)
        #expect(post.contains("\n· Jardines del Buen Retiro ⏰ 18:00–09:00\n"))
        #expect(post.contains("\n· Juan Carlos I\n"))
    }

    @Test func parksWithDifferentHoursEachShowTheirOwn() {
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(alerts: [
            "Jardines del Buen Retiro": (4, "De 18:00 h a 09:00 h"),
            "Parque Quinta de los Molinos": (4, "De 10:00 h a 20:00 h"),
        ]), now: Fixtures.sundayEvening)
        #expect(post.contains("· Jardines del Buen Retiro ⏰ 18:00–09:00\n· Quinta de los Molinos ⏰ 10:00–20:00"))
    }

    @Test("A park on alert without announced hours gets a bare line")
    func alertWithoutHours() {
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(alerts: [
            "Jardines del Buen Retiro": (3, nil),
        ]), now: Fixtures.sundayEvening)
        #expect(post.contains("🟡 Alerta amarilla\n· Jardines del Buen Retiro\n"))
    }

    @Test("Only a leading \"Parque \" is dropped from names")
    func shortNames() {
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(), now: Fixtures.sundayEvening)
        #expect(post.contains("· Juan Carlos I\n"))
        #expect(post.contains("· Rosaleda del Parque del Oeste\n"))
    }

    @Test func endsWithTheWebsiteLink() {
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(), now: Fixtures.sundayEvening)
        #expect(post.hasSuffix("\n\n🌐 Histórico: https://parques.lemambo.com"))
    }

    @Test(arguments: [(1, "🟢"), (2, "🟢"), (3, "🟡"), (4, "🟠"), (5, "🔴"), (6, "🔴")])
    func emojiForCode(code: Int, emoji: String) {
        #expect(StatusFormatter.emojiForCode(code) == emoji)
    }

    @Test("Parks stay open up to orange alert", arguments: [(1, true), (3, true), (4, true), (5, false), (6, false)])
    func isOpen(code: Int, open: Bool) {
        #expect(StatusFormatter.isOpen(code) == open)
    }

    // MARK: - Mastodon's 500-character limit

    @Test("A typical alert day fits in one post")
    func typicalPostFits() {
        // 18 October 2026: six parks on yellow alert overnight, three open
        let alerts = Dictionary(uniqueKeysWithValues: [
            "Jardines del Buen Retiro", "Jardín del Capricho de la Alameda de Osuna",
            "Parque Quinta Fuente del Berro", "Parque Quinta de Torre Arias",
            "Parque Quinta de los Molinos", "Rosaleda del Parque del Oeste",
        ].map { ($0, (code: 3, horario: Optional("De 18:00 h a 09:00 h"))) })
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(alerts: alerts), now: Fixtures.sundayEvening)
        #expect(mastodonLength(post) <= mastodonLimit)
    }

    @Test("Every level at once, each with mixed hours, still fits in one post")
    func busiestPostFits() {
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(alerts: [
            "Jardines del Buen Retiro": (3, "De 18:00 h a 09:00 h"),
            "Jardín del Capricho de la Alameda de Osuna": (3, "De 10:00 h a 20:00 h"),
            "Parque Quinta Fuente del Berro": (4, "De 18:00 h a 09:00 h"),
            "Parque Quinta de Torre Arias": (4, "De 10:00 h a 20:00 h"),
            "Parque Quinta de los Molinos": (5, "De 00:00 h a 24:00 h"),
            "Rosaleda del Parque del Oeste": (5, "De 14:00 h a 24:00 h"),
        ]), now: Fixtures.sundayEvening)
        #expect(mastodonLength(post) <= mastodonLimit)
    }

    @Test("The worst case, all nine parks on alert and the longest weekday, still fits in one post")
    func allParksOnAlertFit() {
        let alerts = Dictionary(uniqueKeysWithValues: Fixtures.parkNames.enumerated().map {
            ($1, (code: 3 + $0 % 3, horario: Optional("De 18:00 h a 09:00 h")))
        })
        let post = StatusFormatter.formatStatus(current: Fixtures.parks(alerts: alerts), now: Fixtures.sundayEvening)
        #expect(mastodonLength(post) <= mastodonLimit)
    }
}
