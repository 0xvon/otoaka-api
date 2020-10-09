import Vapor
import Domain
import FluentKit
import Persistance

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }
    let fanRepository = Persistance.FanRepository(db: app.db)
    let fanProvider = FanProvider(fanRepository)
    try app.register(collection: FanController(fanProvider))
}
