import DomainEntity
import Fluent
import FluentMySQLDriver
import Persistance
import Service
import SotoCore
import Vapor
import JWTKit
import Foundation

protocol Secrets: SimpleNotificationServiceSecrets, DatabaseSecrets {
    var awsAccessKeyId: String { get }
    var awsSecretAccessKey: String { get }
    var awsRegion: String { get }
    var snsPlatformApplicationArn: String { get }
    var auth0Domain: String { get }
}

public struct EnvironmentSecrets: Secrets {
    public init() {
        func require(_ key: String) -> String {
            guard let value = Environment.get(key) else {
                fatalError("Please set \"\(key)\" environment variable")
            }
            return value
        }
        self.awsAccessKeyId = require("AWS_ACCESS_KEY_ID")
        self.awsSecretAccessKey = require("AWS_SECRET_ACCESS_KEY")
        self.awsRegion = require("AWS_REGION")
        self.snsPlatformApplicationArn = require("SNS_PLATFORM_APPLICATION_ARN")
        self.auth0Domain = require("AUTH0_DOMAIN")
        self.databaseURL = require("DATABASE_URL")
    }
    public let awsAccessKeyId: String
    public let awsSecretAccessKey: String
    public let awsRegion: String
    public let snsPlatformApplicationArn: String
    public var auth0Domain: String
    public let databaseURL: String
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

struct AWSClientLifecycle: LifecycleHandler {
    func shutdown(_ application: Application) {
        try! application.awsClient.syncShutdown()
    }
}

// configures your application
public func configure(
    _ app: Application,
    secrets: EnvironmentSecrets = EnvironmentSecrets(),
    authenticator: Authenticator? = nil
) throws {
    let authenticator = try authenticator ?? JWTAuthenticator(auth0Domain: secrets.auth0Domain)
    let adminAuthenticator = AdminGuardAuthenticator(adminUsers: [
        User.ID(rawValue: UUID(uuid: (0x7D, 0xE0, 0x0E, 0x99, 0xFB, 0xD8, 0x4F, 0xA2, 0xB9, 0x50, 0xB8, 0xC2, 0x79, 0xCF, 0xC9, 0xF0)))
    ])
    app.secrets = secrets
    app.awsClient = AWSClient(
        credentialProvider: .static(
            accessKeyId: secrets.awsAccessKeyId, secretAccessKey: secrets.awsSecretAccessKey),
        httpClientProvider: .createNew
    )
    app.lifecycle.use(AWSClientLifecycle())
    try Persistance.setup(
        databases: app.databases,
        secrets: secrets
    )
    try Persistance.setupMigration(
        migrator: app.migrator,
        migrations: app.migrations
    )
    try routes(app, userAuthenticator: authenticator, adminAuthenticator: adminAuthenticator)
}
