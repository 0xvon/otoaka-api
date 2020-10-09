import Domain
import FluentKit
import Persistance
import Vapor

func routes(_ app: Application) throws {
    app.get { _ in
        "It works!"
    }

    app.get("hello") { _ -> String in
        "Hello, world!"
    }
    let fanRepository = Persistance.FanRepository(db: app.db)
    let fanProvider = FanProvider(fanRepository)
    try app.register(collection: FanController(fanProvider))
}
