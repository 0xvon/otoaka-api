import Domain
import FluentKit
import JWTKit
import Persistance
import Vapor
import Endpoint

func routes(_ app: Application) throws {
    app.get { _ in
        "It works!"
    }

    app.get("hello") { _ -> String in
        "Hello, world!"
    }
//    try app.register(collection: FanController())
    try app.register(collection: UserController())
}
