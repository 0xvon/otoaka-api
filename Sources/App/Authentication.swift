import JWTKit
import Vapor
import Persistance
import Domain
import Foundation

class JWTAuthenticator: BearerAuthenticator {
    enum Error: Swift.Error {
        case invalidJWTFormat
        case userNotFound
    }
    let publicKey: RSAKey
    let signer: JWTSigner
    let issuer: String

    init(
        cognitoRegion: String = Environment.get("CONGNITO_IDP_REGION")!,
        cognitoUserPoolId: String = Environment.get("CONGNITO_IDP_USER_POOL_ID")!
    ) throws {
        issuer = "https://cognito-idp.\(cognitoRegion).amazonaws.com/\(cognitoUserPoolId)"
        let jwkURL = URL(string: "\(issuer)/.well-known/jwks.json")!
        publicKey = try RSAKey.public(pem: Data(contentsOf: jwkURL))
        signer = JWTSigner.rs256(key: publicKey)
    }
    
    struct Payload: JWTPayload {
        let sub: SubjectClaim
        let iss: IssuerClaim
        let email: String
        let exp: ExpirationClaim
        func verify(using signer: JWTSigner) throws {
            try exp.verifyNotExpired()
        }
    }

    func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
        let eventLoop = request.eventLoop
        let payload: EventLoopFuture<Payload>
        do {
            payload = try eventLoop.makeSucceededFuture(verifyJWT(bearer: bearer))
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
        let repository = UserRepository(db: request.db)
        let maybeUser = payload.flatMap { payload in
            repository.find(by: Domain.User.ForeignID(value: payload.sub.value))
        }
        return maybeUser.unwrap(orError: Error.userNotFound)
            .always { result in
                guard case let .success(user) = result else { return }
                request.auth.login(user)
            }
            .map { _ in }
    }
    
    func verifyJWT(bearer: BearerAuthorization) throws -> Payload {
        let payload = try signer.verify(bearer.token, as: Payload.self)
        guard payload.iss.value == issuer else {
            throw JWTError.claimVerificationFailure(name: "iss", reason: "Token not provided by Cognito")
        }
        return payload
    }
}

extension Domain.User: Authenticatable {}

extension JWTAuthenticator.Error: AbortError {
    var status: HTTPResponseStatus {
        .unauthorized
    }
}
