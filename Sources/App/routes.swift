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

    let secrets = app.secrets
    let loginTried = try app.routes
        .grouped(
            JWTAuthenticator(
                awsRegion: secrets.awsRegion,
                cognitoUserPoolId: secrets.cognitoUserPoolId))
    try loginTried.register(collection: UserController())
    let signedUp = loginTried.grouped(User.guardMiddleware())
    try signedUp.register(collection: GroupController())
    try signedUp.register(collection: LiveController())
}
