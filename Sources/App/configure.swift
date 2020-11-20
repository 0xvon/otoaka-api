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

struct EnvironmentSecrets: Secrets {
    let awsAccessKeyId = Environment.get("AWS_ACCESS_KEY_ID")!
    let awsAecretAccessKey = Environment.get("AWS_SECRET_ACCESS_KEY")!
    let awsRegion = Environment.get("AWS_REGION")!
    let snsPlatformApplicationArn = Environment.get("SNS_PLATFORM_APPLICATION_ARN")!
    let cognitoUserPoolId = Environment.get("CONGNITO_IDP_USER_POOL_ID")!
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
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    try Persistance.setup(
        databases: app.databases,
        migrator: app.migrator,
        migrations: app.migrations,
        environmentGetter: Environment.get
    )
    app.secrets = EnvironmentSecrets()
    try routes(app)
}
