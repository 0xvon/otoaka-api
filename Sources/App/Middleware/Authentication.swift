import Domain
import Foundation
import JWTKit
import Persistance
import Vapor

#if canImport(FoundationNetworking)
    // Import FoundationNetworking for use of Data(contentsOf:)
    import FoundationNetworking
#endif

class JWTAuthenticator: BearerAuthenticator {
    private let signer: JWTSigners
    private let issuer: String
    private let userRepositoryFactory: (Request) -> Domain.UserRepository

    init(
        awsRegion: String, cognitoUserPoolId: String,
        userRepositoryFactory: @escaping (Request) -> Domain.UserRepository = {
            Persistance.UserRepository(db: $0.db)
        }
    ) throws {
        self.userRepositoryFactory = userRepositoryFactory
        issuer = "https://cognito-idp.\(awsRegion).amazonaws.com/\(cognitoUserPoolId)"
        let jwkURL = URL(string: "\(issuer)/.well-known/jwks.json")!
        let jwks = try JSONDecoder().decode(JWKS.self, from: Data(contentsOf: jwkURL))
        signer = JWTSigners()
        try signer.use(jwks: jwks)
    }

    struct Payload: JWTPayload {
        enum CodingKeys: String, CodingKey {
            case sub
            case iss
            case email
            case username = "cognito:username"
            case exp
        }
        let sub: SubjectClaim
        let iss: IssuerClaim
        let email: String
        let username: String
        let exp: ExpirationClaim
        func verify(using _: JWTSigner) throws {
            try exp.verifyNotExpired()
        }
    }

    func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
        let eventLoop = request.eventLoop
        let payload: Payload
        do {
            payload = try verifyJWT(token: bearer.token)
            request.auth.login(payload)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
        let repository = userRepositoryFactory(request)
        let maybeUser = repository.findByUsername(username: payload.username)
        return maybeUser.always { result in
            guard case let .success(.some(user)) = result else { return }
            request.auth.login(user)
        }
        .map { _ in }
    }

    func verifyJWT(token: String) throws -> Payload {
        let payload = try signer.verify(token, as: Payload.self)
        guard payload.iss.value == issuer else {
            throw JWTError.claimVerificationFailure(
                name: "iss", reason: "Token not provided by Cognito")
        }
        return payload
    }
}

extension Domain.User: Authenticatable {}
extension JWTAuthenticator.Payload: Authenticatable {}
