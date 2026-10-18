import Foundation
import Testing
import TootSDK
@testable import EstadoParques

struct MastodonPosterTests {
    /// Stands in for Mastodon: fails with the queued errors in order, then succeeds
    final class FakeMastodon {
        var failures: [Error]
        var attempts: [(text: String, instance: String, token: String)] = []
        var waits: [UInt64] = []

        init(failing failures: [Error] = []) {
            self.failures = failures
        }

        func publish(_ text: String, _ instance: String, _ token: String) async throws {
            attempts.append((text, instance, token))
            if failures.isEmpty == false {
                throw failures.removeFirst()
            }
        }

        func sleep(_ seconds: UInt64) async throws {
            waits.append(seconds)
        }
    }

    struct Rejected: Error, Equatable {}

    let environment = ["MASTODON_INSTANCE": "mastodon.social", "MASTODON_ACCESS_TOKEN": "token"]

    private func post(to mastodon: FakeMastodon, environment: [String: String]? = nil) async throws {
        try await MastodonPoster.post(
            text: "Hola",
            environment: environment ?? self.environment,
            publish: mastodon.publish,
            sleep: mastodon.sleep
        )
    }

    static func httpError(_ status: Int) -> Error {
        let response = HTTPURLResponse(
            url: URL(string: "https://mastodon.social/api/v1/statuses")!,
            statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return TootSDKError.invalidStatusCode(data: Data(), response: response)
    }

    @Test func publishesOnceWhenMastodonAnswers() async throws {
        let mastodon = FakeMastodon()
        try await post(to: mastodon)
        #expect(mastodon.attempts.count == 1)
        #expect(mastodon.attempts.first?.instance == "mastodon.social")
        #expect(mastodon.waits.isEmpty)
    }

    @Test("Transient failures are retried after 5 s and then 15 s")
    func transientFailuresAreRetried() async throws {
        let mastodon = FakeMastodon(failing: [Self.httpError(503), URLError(.timedOut)])
        try await post(to: mastodon)
        #expect(mastodon.attempts.count == 3)
        #expect(mastodon.waits == [5, 15])
    }

    @Test("After three transient failures the last error reaches the caller")
    func persistentFailureIsThrown() async throws {
        let mastodon = FakeMastodon(failing: [Self.httpError(503), Self.httpError(503), URLError(.notConnectedToInternet)])
        await #expect(throws: URLError.self) {
            try await post(to: mastodon)
        }
        #expect(mastodon.attempts.count == 3)
    }

    @Test("A rejected post is not retried")
    func rejectionIsNotRetried() async throws {
        let mastodon = FakeMastodon(failing: [Rejected()])
        await #expect(throws: Rejected()) {
            try await post(to: mastodon)
        }
        #expect(mastodon.attempts.count == 1)
        #expect(mastodon.waits.isEmpty)
    }

    @Test("Without credentials nothing is attempted", arguments: [
        [String: String](),
        ["MASTODON_INSTANCE": "mastodon.social"],
        ["MASTODON_ACCESS_TOKEN": "token"],
    ])
    func missingCredentials(environment: [String: String]) async throws {
        let mastodon = FakeMastodon()
        try await post(to: mastodon, environment: environment)
        #expect(mastodon.attempts.isEmpty)
    }

    @Test("Rate limits and server errors are transient; client errors are not",
          arguments: [(429, true), (500, true), (503, true), (599, true), (401, false), (404, false), (422, false)])
    func statusCodes(status: Int, transient: Bool) {
        #expect(MastodonPoster.isTransient(Self.httpError(status)) == transient)
    }

    @Test func networkErrorsAreTransient() {
        #expect(MastodonPoster.isTransient(URLError(.networkConnectionLost)))
        #expect(MastodonPoster.isTransient(Rejected()) == false)
    }
}
