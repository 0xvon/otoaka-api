import Domain
import Endpoint
import FluentKit
import JWTKit
import Persistance
import Vapor

func routes(
    _ app: Application,
    userAuthenticator: Authenticator,
    adminAuthenticator: Middleware
) throws {
    app.routes.defaultMaxBodySize = "500kb"
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [
            .accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent,
            .accessControlAllowOrigin,
        ]
    )
    let corsMiddleware = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(corsMiddleware)

    app.get { _ in
        "It works!"
    }

    app.get("hello") { _ -> String in
        "Hello, world!"
    }

    try app.register(collection: PublicController())
    let loginTried = app.routes.grouped(userAuthenticator)
    try loginTried.register(collection: UserController())
    let signedUp = loginTried.grouped(
        User.guardMiddleware(
            throwing: Abort(
                .unauthorized, reason: "\(User.self) not authenticated.", stackTrace: nil)
        ))
    try signedUp.register(collection: GroupController())
    try signedUp.register(collection: LiveController())
    try signedUp.register(collection: UserSocialController())
    try signedUp.register(collection: MessageController())
    try signedUp.register(collection: SocialTipController())
    try signedUp.register(collection: PointController())
    try signedUp.grouped(adminAuthenticator)
        .register(collection: ExternalController())
//    try signedUp.register(collection: ExternalController())
}
