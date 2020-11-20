import Fluent
import FluentMySQLDriver
import Persistance
import Vapor

protocol Secrets {
    var awsAccessKeyId: String { get }
    var awsAecretAccessKey: String { get }
    var awsRegion: String { get }
    var snsPlatformApplicationArn: String { get }
    var cognitoUserPoolId: String { get }
}

struct EnvironmentSecrets: Secrets, DatabaseSecrets {
    init() {
        func require(_ key: String) -> String {
            guard let value = Environment.get(key) else {
                fatalError("Please set \"\(key)\" environment variable")
            }
            return value
        }
        self.awsAccessKeyId = require("AWS_ACCESS_KEY_ID")
        self.awsAecretAccessKey = require("AWS_SECRET_ACCESS_KEY")
        self.awsRegion = require("AWS_REGION")
        self.snsPlatformApplicationArn = require("SNS_PLATFORM_APPLICATION_ARN")
        self.cognitoUserPoolId = require("CONGNITO_IDP_USER_POOL_ID")
        self.databaseURL = require("DATABASE_URL")
    }
    let awsAccessKeyId: String
    let awsAecretAccessKey: String
    let awsRegion: String
    let snsPlatformApplicationArn: String
    let cognitoUserPoolId: String
    let databaseURL: String
}

extension Application {
    struct SecretsKey: StorageKey {
        typealias Value = Secrets
    }
    var secrets: Secrets {
        get {
            guard let secrets = storage[SecretsKey.self] else {
                fatalError("Please set app.secrets")
            }
            return secrets
        }
        set { storage[SecretsKey.self] = newValue }
    }
}

// configures your application
public func configure(_ app: Application) throws {
    let secrets = EnvironmentSecrets()
    app.secrets = secrets
    try Persistance.setup(
        databases: app.databases,
        migrator: app.migrator,
        migrations: app.migrations,
        secrets: secrets
    )
    try routes(app)
}
