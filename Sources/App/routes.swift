import Domain
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
    try app.register(collection: FanController())
    try app.register(collection: UserController())
}

import Endpoint

func playground() {
    let route = const("bands")/int()/const("fans")/string()/string()/int()
//    let route: Route1<(String, Int)> = curry { ($1, $2) } <^> match("Hello") <*> string() <*> int()
    print(type(of: route))
}
