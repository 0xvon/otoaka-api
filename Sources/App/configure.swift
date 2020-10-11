import Fluent
import FluentMySQLDriver
import Persistance
import Vapor

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
    try routes(app)
}
