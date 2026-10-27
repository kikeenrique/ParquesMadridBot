import Foundation

enum StatusFormatter {
    static func isOpen(_ code: Int) -> Bool {
        code < 5
    }

    static func emojiForCode(_ code: Int) -> String {
        if code >= 5 { return "🔴" }
        if code == 4 { return "🟠" }
        if code == 3 { return "🟡" }
        return "🟢"
    }

    private struct AlertGroup {
        let emoji: String
        let header: String
        let showSchedule: Bool
        let range: (Int) -> Bool
    }

    /// One line per park, alerts first, each with its hours ("18:00–09:00"). Hours carry no day: parks close
    /// at night, and the next morning's run posts the new forecast.
    static func formatStatus(current: [String: ParkAttributes], now: Date = Date()) -> String {
        let formatter = DateFormatter()
        // CI runners use UTC; posts must show Madrid local time
        formatter.timeZone = TimeZone(identifier: "Europe/Madrid")
        formatter.locale = Locale(identifier: "es_ES")
        // es_ES abbreviates "dom." with a dot: "2026-10-18 dom a las 18:27"
        formatter.dateFormat = "yyyy-MM-dd EEE 'a las' HH:mm"
        let dateString = formatter.string(from: now).replacingOccurrences(of: ".", with: "")

        let groups: [AlertGroup] = [
            AlertGroup(emoji: "🟡", header: "Alerta amarilla", showSchedule: true) { $0 == 3 },
            AlertGroup(emoji: "🟠", header: "Alerta naranja", showSchedule: true) { $0 == 4 },
            AlertGroup(emoji: "🔴", header: "Cerrados", showSchedule: true) { $0 >= 5 },
            AlertGroup(emoji: "🟢", header: "Abiertos", showSchedule: false) { $0 < 3 },
        ]

        func shortName(_ name: String) -> String {
            name.hasPrefix("Parque ") ? String(name.dropFirst("Parque ".count)) : name
        }

        var lines: [String] = ["Parques de Madrid, \(dateString)"]

        for group in groups {
            let parks = current
                .filter { group.range($0.value.alertaDescripcion) }
                .sorted { $0.key < $1.key }

            guard !parks.isEmpty else { continue }

            lines.append("")
            lines.append("\(group.emoji) \(group.header)")
            for (name, attrs) in parks {
                let hours = group.showSchedule ? attrs.horarioIncidencia.map(WebsiteGenerator.compactSchedule) : nil
                lines.append("· \(shortName(name))" + (hours.map { " ⏰ \($0)" } ?? ""))
            }
        }

        lines.append("")
        lines.append("🌐 Histórico: https://parques.lemambo.com")

        return lines.joined(separator: "\n")
    }
}
