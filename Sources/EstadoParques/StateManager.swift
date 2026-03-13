import Foundation

enum StateManager {
    static func loadPreviousState(from path: String) -> [String: Int] {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        return state
    }

    static func saveState(_ state: [String: Int], to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: URL(fileURLWithPath: path))
    }

    static func appendStatistics(_ events: [ChangeEvent], to path: String) throws {
        guard !events.isEmpty else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var lines = ""
        for event in events {
            let data = try encoder.encode(event)
            if let json = String(data: data, encoding: .utf8) {
                lines += json + "\n"
            }
        }

        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            if let lineData = lines.data(using: .utf8) {
                handle.write(lineData)
            }
            handle.closeFile()
        } else {
            try lines.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
