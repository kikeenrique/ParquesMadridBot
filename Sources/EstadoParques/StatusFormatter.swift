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

    static func formatStatus(current: [String: ParkAttributes]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        let dateString = formatter.string(from: Date())

        let groups: [AlertGroup] = [
            AlertGroup(emoji: "🟢", header: "Abiertos", showSchedule: false) { $0 < 3 },
            AlertGroup(emoji: "🟡", header: "Amarilla", showSchedule: false) { $0 == 3 },
            AlertGroup(emoji: "🟠", header: "Naranja", showSchedule: true) { $0 == 4 },
            AlertGroup(emoji: "🔴", header: "Cerrados", showSchedule: true) { $0 >= 5 },
        ]

        var lines: [String] = ["Estado de parques de Madrid a fecha \(dateString)."]

        for group in groups {
            let parks = current
                .filter { group.range($0.value.alertaDescripcion) }
                .sorted { $0.key < $1.key }

            guard !parks.isEmpty else { continue }

            lines.append("")
            lines.append("\(group.emoji) \(group.header):")

            for (name, attrs) in parks {
                lines.append("· \(name)")
                if group.showSchedule, let horario = attrs.horarioIncidencia, !horario.isEmpty {
                    let compact = horario
                        .replacingOccurrences(of: "de ", with: "")
                        .replacingOccurrences(of: " a ", with: "-")
                    lines.append("  ⏰ \(compact)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
