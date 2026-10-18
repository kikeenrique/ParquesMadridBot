import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// `--website <dir>` only regenerates the static site from the saved state and history
if let flag = CommandLine.arguments.firstIndex(of: "--website"), flag + 1 < CommandLine.arguments.count {
    do {
        try WebsiteGenerator.generate(into: CommandLine.arguments[flag + 1])
        print("🌐 Web generada en \(CommandLine.arguments[flag + 1])")
        exit(0)
    } catch {
        print("❌ Error generando la web: \(error)")
        exit(1)
    }
}

let isProduction = ProcessInfo.processInfo.environment["PRODUCTION"]?.lowercased() == "true"
print("🔍 Iniciando bot. Modo producción: \(isProduction)")

do {
    try await Bot(isProduction: isProduction).run()
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
