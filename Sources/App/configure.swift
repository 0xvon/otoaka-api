import Fluent
import FluentMySQLDriver
import Persistance
import Service
import SotoCore
import Vapor
import JWTKit

protocol Secrets: SimpleNotificationServiceSecrets, DatabaseSecrets {
    var awsAccessKeyId: String { get }
    var awsSecretAccessKey: String { get }
    var awsRegion: String { get }
    var snsPlatformApplicationArn: String { get }
    var cognitoUserPoolId: String { get }
}

public struct EnvironmentSecrets: Secrets {
    init() {
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
        self.cognitoUserPoolId = require("CONGNITO_IDP_USER_POOL_ID")
        self.databaseURL = require("DATABASE_URL")
    }
    public let awsAccessKeyId: String
    public let awsSecretAccessKey: String
    public let awsRegion: String
    public let snsPlatformApplicationArn: String
    public let cognitoUserPoolId: String
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
    let authenticator = try authenticator ?? JWTAuthenticator(
        awsRegion: secrets.awsRegion, cognitoUserPoolId: secrets.cognitoUserPoolId
    )
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
        migrations: app.migrations,
        cognitoUserMigrator: {
            UserPoolMigrator_20210213(
                awsClient: app.awsClient, userPoolId: secrets.cognitoUserPoolId
            ).migrateUsers(users: $0)
        }
    )
    try routes(app, authenticator: authenticator)
}
