import Configuration
import PlnFlrWeb
import Vapor

@main
struct Entrypoint {
    static func main() async throws {
        let config = ConfigReader(providers: [
            CommandLineArgumentsProvider(),
            EnvironmentVariablesProvider(),
        ])
        let app = try await Application(configReader: config)
        do {
            try await configure(app)
            try await app.run()
            try await app.shutdown()
        } catch {
            try? await app.shutdown()
            throw error
        }
    }
}
