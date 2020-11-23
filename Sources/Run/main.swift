import App
import Logging
import LoggingDiscord
import Vapor

var env = try Environment.detect()
func provideDiscordLoggerFactory() -> ((_ label: String) -> DiscordLogHandler)? {
    guard let discordLoggingWebhookString = Environment.get("DISCORD_LOGGING_WEBHOOK_URL") else {
        print("[ WARNING ] DISCORD_LOGGING_WEBHOOK_URL is not set")
        return nil
    }
    guard let discordLoggingWebhookURL = URL(string: discordLoggingWebhookString) else {
        print("[ WARNING ] DISCORD_LOGGING_WEBHOOK_URL is ignored because it's invalid URL form")
        return nil
    }
    return { label in
        return DiscordLogHandler(
            label: label, userName: "rocket-api",
            avatarURL: URL(string: "https://github.com/wall-of-death.png")!,
            webhookURL: discordLoggingWebhookURL,
            level: .error
        )
    }
}

try LoggingSystem.bootstrap(from: &env) { level in
    let console = Terminal()
    let discordLoggerFactory = provideDiscordLoggerFactory()
    return { label in
        let optionalHandlers = [discordLoggerFactory].compactMap { $0?(label) }
        return MultiplexLogHandler(
            [
                ConsoleLogger(label: label, console: console, level: level)
            ] + optionalHandlers)
    }
}
let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()
