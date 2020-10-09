import Fluent
import FluentMySQLDriver
import Persistance
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    try Persistance.setup(app)
    try routes(app)
}
