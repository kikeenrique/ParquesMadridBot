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
        formatter.dateFormat = "yyyy-MM-dd"
        let datePart = formatter.string(from: Date())
        formatter.dateFormat = "HH:mm"
        let timePart = formatter.string(from: Date())
        let dateString = "\(datePart) a las \(timePart)"

        let groups: [AlertGroup] = [
            AlertGroup(emoji: "🟢", header: "Abiertos", showSchedule: false) { $0 < 3 },
            AlertGroup(emoji: "🟡", header: "Alerta amarilla", showSchedule: false) { $0 == 3 },
            AlertGroup(emoji: "🟠", header: "Alerta naranja", showSchedule: true) { $0 == 4 },
            AlertGroup(emoji: "🔴", header: "Cerrados", showSchedule: true) { $0 >= 5 },
        ]

        func shortName(_ name: String) -> String {
            name.replacingOccurrences(of: "Parque ", with: "")
        }

        var lines: [String] = ["Estado de parques de Madrid a fecha \(dateString)."]

        for group in groups {
            let parks = current
                .filter { group.range($0.value.alertaDescripcion) }
                .sorted { $0.key < $1.key }

            guard !parks.isEmpty else { continue }

            lines.append("")
            lines.append("\(group.emoji) \(group.header):")

            if group.showSchedule {
                var bySchedule: [(String, [String])] = []
                for (name, attrs) in parks {
                    let schedule = attrs.horarioIncidencia
                        .map { $0.replacingOccurrences(of: "de ", with: "").replacingOccurrences(of: " a ", with: "-") }
                        ?? ""
                    if let idx = bySchedule.firstIndex(where: { $0.0 == schedule }) {
                        bySchedule[idx].1.append(name)
                    } else {
                        bySchedule.append((schedule, [name]))
                    }
                }
                for (schedule, names) in bySchedule {
                    if !schedule.isEmpty {
                        lines.append("⏰ \(schedule)")
                    }
                    for name in names {
                        lines.append("· \(shortName(name))")
                    }
                }
            } else {
                for (name, _) in parks {
                    lines.append("· \(shortName(name))")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
