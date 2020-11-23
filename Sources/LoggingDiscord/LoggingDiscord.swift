import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

public class DiscordLogHandler: LogHandler {
    public let label: String
    public var userName: String
    
    /// See `LogHandler.metadata`.
    public var metadata: Logger.Metadata
    
    /// See `LogHandler.logLevel`.
    public var logLevel: Logger.Level

    public var webhookURL: URL
    public var avatarURL: URL

    private let session: URLSession

    public init(
        label: String, userName: String, avatarURL: URL,
        webhookURL: URL, level: Logger.Level = .error, session: URLSession = .shared, metadata: Logger.Metadata = [:]
    ) {
        self.label = label
        self.userName = userName
        self.metadata = metadata
        self.logLevel = level
        self.webhookURL = webhookURL
        self.avatarURL = avatarURL
        self.session = session
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set(newValue) { metadata[key] = newValue }
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        var text: String = ""

        if self.logLevel <= .trace {
            text += "[ \(self.label) ] "
        }
        text += "[ \(level.name) ]" + " " + message.description
        let allMetadata = (metadata ?? [:]).merging(self.metadata) { (a, _) in a }

        if !allMetadata.isEmpty {
            // only log metadata if not empty
            text += " " + allMetadata.sortedDescriptionWithoutQuotes
        }

        if self.logLevel <= .debug {
            text += " (" + file + ":" + line.description + ")"
        }
        let webhook = DiscordWebhook(username: userName, avatarUrl: avatarURL.absoluteString, content: "`\(text)`")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body: Data
        do {
            body = try encoder.encode(webhook)
        } catch {
            print("[ ERROR ] DiscordLogHandler.log failed to encode body '\(error)' (\(#file):\(#line)")
            return
        }
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = session.dataTask(with: request) { data, response, error in
            if let data = data, let response = response as? HTTPURLResponse {
                guard 200..<299 ~= response.statusCode else {
                    let errorResponse = String(data: data, encoding: .utf8)
                    print("[ ERROR ] DiscordLogHandler.log failed to send request '\(errorResponse ?? "no message")' (\(#file):\(#line)")
                    return
                }
            } else if let error = error {
                print("[ ERROR ] DiscordLogHandler.log failed to send request '\(error)' (\(#file):\(#line)")
            } else {
                print("[ ERROR ] DiscordLogHandler.log got unexpected request result (\(#file):\(#line)")
            }
        }
        task.resume()
    }
}

struct DiscordWebhook: Codable {
    let username: String
    let avatarUrl: String
    let content: String
}

private extension Logger.Metadata {
    var sortedDescriptionWithoutQuotes: String {
        let contents = Array(self)
            .sorted(by: { $0.0 < $1.0 })
            .map { "\($0.description): \($1)" }
            .joined(separator: ", ")
        return "[\(contents)]"
    }
}

fileprivate extension Logger.Level {
    var name: String {
        switch self {
        case .trace: return "TRACE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}
