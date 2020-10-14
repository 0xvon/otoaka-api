import Domain
import Foundation
import JWTKit
import Persistance
import Vapor

class JWTAuthenticator: BearerAuthenticator {
    private let signer: JWTSigners
    private let issuer: String
    private let userRepositoryFactory: (Request) -> Domain.UserRepository

    init(
        cognitoRegion: String = Environment.get("CONGNITO_IDP_REGION")!,
        cognitoUserPoolId: String = Environment.get("CONGNITO_IDP_USER_POOL_ID")!,
        userRepositoryFactory: @escaping (Request) -> Domain.UserRepository = {
            Persistance.UserRepository(db: $0.db)
        }
    ) throws {
        self.userRepositoryFactory = userRepositoryFactory
        self.issuer = "https://cognito-idp.\(cognitoRegion).amazonaws.com/\(cognitoUserPoolId)"
        let jwkURL = URL(string: "\(issuer)/.well-known/jwks.json")!
        let jwks = try JSONDecoder().decode(JWKS.self, from: Data(contentsOf: jwkURL))
        self.signer = JWTSigners()
        try signer.use(jwks: jwks)
    }

    struct Payload: JWTPayload {
        let sub: SubjectClaim
        let iss: IssuerClaim
        let email: String
        let exp: ExpirationClaim
        func verify(using _: JWTSigner) throws {
            try exp.verifyNotExpired()
        }
    }

    func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
        let eventLoop = request.eventLoop
        let payload: EventLoopFuture<Payload>
        do {
            let verifiedPayload = try verifyJWT(bearer: bearer)
            request.auth.login(verifiedPayload)
            payload = eventLoop.makeSucceededFuture(verifiedPayload)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
        let repository = userRepositoryFactory(request)
        let maybeUser = payload.flatMap { payload in
            repository.find(by: Domain.User.ForeignID(value: payload.sub.value))
        }
        return maybeUser.always { result in
            guard case let .success(.some(user)) = result else { return }
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
extension JWTAuthenticator.Payload: Authenticatable {}
