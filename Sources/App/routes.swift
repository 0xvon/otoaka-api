import Domain
import Endpoint
import FluentKit
import JWTKit
import Persistance
import Vapor

func routes(_ app: Application) throws {
    app.get { _ in
        "It works!"
    }

    app.get("hello") { _ -> String in
        "Hello, world!"
    }

    try app.register(collection: UserController())
    try app.register(collection: GroupController())
}
