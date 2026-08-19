import Foundation
import TootSDK

enum MastodonPoster {
    /// Delays between publish attempts. Instances fronted by a cache return
    /// transient 503s, so a couple of retries usually clears them.
    static let retryDelaysInSeconds: [UInt64] = [5, 15]

    static func post(text: String) async throws {
        guard let instance = ProcessInfo.processInfo.environment["MASTODON_INSTANCE"],
              let token = ProcessInfo.processInfo.environment["MASTODON_ACCESS_TOKEN"]
        else {
            print("❌ Error: MASTODON_INSTANCE and MASTODON_ACCESS_TOKEN must be set")
            return
        }

        for (attempt, delay) in retryDelaysInSeconds.enumerated() {
            do {
                try await publish(text: text, instance: instance, token: token)
                return
            } catch {
                guard isTransient(error) else { throw error }
                print("⚠️ Intento \(attempt + 1) fallido (\(error.localizedDescription)); reintentando en \(delay)s")
                try await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }

        // Last attempt: let whatever it throws reach the caller
        try await publish(text: text, instance: instance, token: token)
    }

    private static func publish(text: String, instance: String, token: String) async throws {
        let instanceURL = URL(string: "https://\(instance)")!
        let client = try await TootClient(
            connect: instanceURL,
            clientName: "EstadoParquesMadrid",
            accessToken: token,
            scopes: ["write:statuses"]
        )

        let params = PostParams(
            post: text,
            mediaIds: [],
            poll: nil,
            inReplyToId: nil,
            sensitive: nil,
            spoilerText: nil,
            visibility: .public,
            language: "es",
            contentType: nil,
            inReplyToConversationId: nil
        )

        let _ = try await client.publishPost(params)
        print("✅ Publicado en Mastodon (\(instance))")
    }

    /// Server-side and network failures are worth retrying; a rejected post is not.
    private static func isTransient(_ error: Error) -> Bool {
        if case let TootSDKError.invalidStatusCode(_, response) = error {
            return response.statusCode == 429 || (500...599).contains(response.statusCode)
        }
        if error is URLError {
            return true
        }
        return false
    }
}
