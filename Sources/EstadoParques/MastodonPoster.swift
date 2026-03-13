import Foundation
import TootSDK

enum MastodonPoster {
    static func post(text: String) async throws {
        guard let instance = ProcessInfo.processInfo.environment["MASTODON_INSTANCE"],
              let token = ProcessInfo.processInfo.environment["MASTODON_ACCESS_TOKEN"]
        else {
            print("❌ Error: MASTODON_INSTANCE and MASTODON_ACCESS_TOKEN must be set")
            return
        }

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
}
