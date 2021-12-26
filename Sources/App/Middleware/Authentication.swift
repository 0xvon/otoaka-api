import Domain
import Foundation
import JWTKit
import Persistance
import SotoCognitoIdentityProvider
import Vapor

#if canImport(FoundationNetworking)
    // Import FoundationNetworking for use of Data(contentsOf:)
    import FoundationNetworking
#endif

class JWTAuthenticator: BearerAuthenticator {
    private let signer: JWTSigners
    private let issuer: String
    private let userRepositoryFactory: (Request) -> Domain.UserRepository

    convenience init(
        auth0Domain: String,
        userRepositoryFactory: @escaping (Request) -> Domain.UserRepository = {
            Persistance.UserRepository(db: $0.db)
        }
    ) throws {
        let issuer = "\(auth0Domain)/"
        let jwkURL = URL(string: "\(issuer).well-known/jwks.json")!
        let jwks = try JSONDecoder().decode(JWKS.self, from: Data(contentsOf: jwkURL))
        let signer = JWTSigners()
        try signer.use(jwks: jwks)
        self.init(signer: signer, issuer: issuer, userRepositoryFactory: userRepositoryFactory)
    }
    init(
        signer: JWTSigners, issuer: String,
        userRepositoryFactory: @escaping (Request) -> Domain.UserRepository = {
            Persistance.UserRepository(db: $0.db)
        }
    ) {
        self.signer = signer
        self.issuer = issuer
        self.userRepositoryFactory = userRepositoryFactory
    }

    struct Payload: JWTPayload {
        enum CodingKeys: String, CodingKey {
            case sub
            case iss
            case email
            case exp
        }
        var sub: SubjectClaim
        let iss: IssuerClaim
        let email: String?
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
        let maybeUser = repository.findByUsername(username: payload.sub.value)
        return maybeUser.always { result in
            guard case let .success(.some(user)) = result else { return }
            request.auth.login(user)
        }
        .map { _ in }
    }

    func verifyJWT(token: String) throws -> Payload {
        var payload = try signer.verify(token, as: Payload.self)
        payload.sub.value = convertToCognitoUsername(payload.sub.value)
        guard payload.iss.value == issuer else {
            throw JWTError.claimVerificationFailure(
                name: "iss", reason: "Token not provided by Auth0")
        }
        return payload
    }
}

public func convertToCognitoUsername(_ sub: String) -> String {
    return
        sub
        .replacingOccurrences(of: "|", with: "_")
        .replacingOccurrences(of: "apple", with: "SignInWithApple")
        .replacingOccurrences(of: "facebook", with: "Facebook")
        .replacingOccurrences(of: "google-oauth2", with: "Google")
        .replacingOccurrences(of: "auth0_", with: "")
}
extension Domain.User: Authenticatable {}
extension JWTAuthenticator.Payload: Authenticatable {}

