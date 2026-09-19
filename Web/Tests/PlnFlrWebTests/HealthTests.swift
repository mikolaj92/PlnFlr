import Testing
import VaporTesting
import PlnFlrWeb

@Test func healthzReturnsOk() async throws {
    try await withApp(configure: configure) { app in
        try await app.testing { client in
            let res = try await client.get("healthz")
            #expect(res.status == .ok)
            let body = try await res.content.decode(Health.self)
            #expect(body.ok == "plnflr")
        }
    }
}
