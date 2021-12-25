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
        awsRegion: String, cognitoUserPoolId: String,
        userRepositoryFactory: @escaping (Request) -> Domain.UserRepository = {
            Persistance.UserRepository(db: $0.db)
        }
    ) throws {
        let issuer = "https://cognito-idp.\(awsRegion).amazonaws.com/\(cognitoUserPoolId)"
        let jwkURL = URL(string: "\(issuer)/.well-known/jwks.json")!
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

class UserPoolMigrator_20210213 {
    typealias User = PersistanceUser
    let userPoolId: String
    let region: String = Environment.get("AWS_REGION")!
    let cognito: CognitoIdentityProvider

    init(awsClient: AWSClient, userPoolId: String) {
        self.cognito = CognitoIdentityProvider(client: awsClient, region: Region(rawValue: region))
        self.userPoolId = userPoolId
    }

    func migrateUsers(
        users: [User]
    ) -> EventLoopFuture<Void> {

        let cognitoUsers = cognito._listUsersPaginator(
            CognitoIdentityProvider.ListUsersRequest(userPoolId: userPoolId),
            [CognitoIdentityProvider._UserType]()
        ) {
            (users, response, eventLoop) -> EventLoopFuture<
                (Bool, [CognitoIdentityProvider._UserType])
            > in
            eventLoop.makeSucceededFuture((true, users + (response.users ?? [])))
        }

        return
            cognitoUsers
            .map { cognitoUsers in
                users.forEach {
                    self.migrateUser(
                        user: $0, cognitoId: $0.cognitoId,
                        cognitoUsers: cognitoUsers
                    )
                }
            }
    }

    func migrateUser(
        user: User, cognitoId: String,
        cognitoUsers: [CognitoIdentityProvider._UserType]
    ) {
        guard let username = getUsername(cognitoId: cognitoId, cognitoUsers: cognitoUsers) else {
            return
        }
        user.cognitoUsername = username
    }

    fileprivate func getUsername(
        cognitoId: String, cognitoUsers: [CognitoIdentityProvider._UserType]
    ) -> String? {
        guard let user = cognitoUsers.first(where: { $0.sub == cognitoId }) else {
            return nil
        }
        return user.username
    }
}

extension CognitoIdentityProvider._UserType {
    fileprivate var sub: String? {
        attributes?.first(where: { $0.name == "sub" })?.value
    }
}

extension CognitoIdentityProvider {
    struct _ListUsersResponse: AWSDecodableShape {
        /// An identifier that was returned from the previous call to this operation, which can be used to return the next set of items in the list.
        let paginationToken: String?
        /// The users returned in the request to list users.
        let users: [_UserType]?

        private enum CodingKeys: String, CodingKey {
            case paginationToken = "PaginationToken"
            case users = "Users"
        }
    }
    struct _UserType: AWSDecodableShape {
        /// A container with information about the user type attributes.
        let attributes: [CognitoIdentityProvider.AttributeType]?
        /// The user name of the user you wish to describe.
        let username: String?

        enum CodingKeys: String, CodingKey {
            case attributes = "Attributes"
            case username = "Username"
        }
    }

    func _listUsers(
        _ input: ListUsersRequest, logger: Logger = AWSClient.loggingDisabled,
        on eventLoop: EventLoop? = nil
    ) -> EventLoopFuture<_ListUsersResponse> {
        return self.client.execute(
            operation: "ListUsers", path: "/", httpMethod: .POST, serviceConfig: self.config,
            input: input, logger: logger, on: eventLoop)
    }

    func _listUsersPaginator<Result>(
        _ input: ListUsersRequest,
        _ initialValue: Result,
        logger: Logger = AWSClient.loggingDisabled,
        on eventLoop: EventLoop? = nil,
        onPage: @escaping (Result, _ListUsersResponse, EventLoop) -> EventLoopFuture<(Bool, Result)>
    ) -> EventLoopFuture<Result> {
        return client.paginate(
            input: input,
            initialValue: initialValue,
            command: _listUsers,
            tokenKey: \_ListUsersResponse.paginationToken,
            on: eventLoop,
            onPage: onPage
        )
    }
}
