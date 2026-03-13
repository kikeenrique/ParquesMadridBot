import Foundation

enum StatusFormatter {
    static let invisibleSpace = "\u{3000}"
    static let changeIndicator = "🆕"

    static func isOpen(_ code: Int) -> Bool {
        code < 5
    }

    static func emojiForCode(_ code: Int) -> String {
        if code >= 5 { return "🔴" }
        if code == 4 { return "🟠" }
        if code == 3 { return "🟡" }
        return "🟢"
    }

    static func formatStatus(current: [String: Int], changes: Set<String>) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        let dateString = formatter.string(from: Date())

        var lines: [String] = ["Estado de parques de Madrid a fecha \(dateString).", ""]

        let sortedParks = current.keys.sorted()
        for park in sortedParks {
            let code = current[park]!
            let emoji = emojiForCode(code)
            let marker = changes.contains(park) ? changeIndicator : invisibleSpace
            lines.append("\(marker) \(emoji) \(park)")
        }

        return lines.joined(separator: "\n")
    }
}
