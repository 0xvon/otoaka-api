import AsyncHTTPClient
import CognitoIdentityProvider
import Endpoint
import Foundation
import NIO
import NIOHTTP1
import StubKit

class AppUser {
    private let cognito: CognitoClient
    let userName: String
    let token: String
    let user: User

    init(userName: String, cognito: CognitoClient, token: String, user: User) {
        self.userName = userName
        self.cognito = cognito
        self.token = token
        self.user = user
    }
    deinit {
    }
}

extension NIOHTTP1.HTTPMethod {
    static func translate(from endpointMethod: Endpoint.HTTPMethod) -> Self {
        switch endpointMethod {
        case .post: return .POST
        case .get: return .GET
        case .put: return .PUT
        case .delete: return .DELETE
        }
    }
}

class AppClient {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let baseURL: URL
    private let http: AsyncHTTPClient.HTTPClient
    private let cognito: CognitoClient
    init(baseURL: URL, http: AsyncHTTPClient.HTTPClient, cognito: CognitoClient) {
        self.baseURL = baseURL
        self.http = http
        self.cognito = cognito
    }

    func makeHeaders(for user: AppUser) -> HTTPHeaders {
        makeHeaders(for: user.token)
    }

    func makeHeaders(for token: String) -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: "Authorization", value: "Bearer \(token)")
        headers.add(name: "Content-Type", value: "application/json; charset=utf8")
        return headers
    }
    func execute<E>(_: E.Type, uri: E.URI = E.URI(), request: E.Request? = nil, as user: AppUser)
        -> EventLoopFuture<E.Response> where E: EndpointProtocol
    {
        execute(E.self, uri: uri, request: request, as: user.token)
    }
    func execute<E>(_: E.Type, uri: E.URI = E.URI(), request: E.Request? = nil, as token: String)
        -> EventLoopFuture<E.Response> where E: EndpointProtocol
    {
        let url: URL
        do {
            url = try uri.encode(baseURL: baseURL)
            let body = try request.map { try encoder.encode($0) }
            let request = try HTTPClient.Request(
                url: url, method: .translate(from: E.method),
                headers: makeHeaders(for: token),
                body: body.map(AsyncHTTPClient.HTTPClient.Body.data)
            )
            return http.execute(request: request)
                .flatMapThrowing { [decoder] in
                    var body = $0.body ?? ByteBuffer()
                    return try body.readJSONDecodable(
                        E.Response.self, decoder: decoder, length: body.readableBytes)!
                }
        } catch {
            fatalError()
        }
    }
}

class CognitoClient {
    struct User: Codable {
        let token: String
        let sub: String
    }

    let cognito: CognitoIdentityProvider
    let userPoolId: String = Environment.get("CONGNITO_IDP_USER_POOL_ID")!
    let region: String = Environment.get("AWS_REGION")!
    let clientId: String = Environment.get("CONGNITO_IDP_CLIENT_ID")!
    init() {
        cognito = CognitoIdentityProvider(region: Region(rawValue: region)!)
    }

    func createToken(userName: String, email: String? = nil, password: String = "Passw0rd!!")
        -> EventLoopFuture<User>
    {
        let email = email ?? "\(userName)@example.com"
        let tempPassword = "Passw0rd!"
        return cognito.adminCreateUser(
            .init(temporaryPassword: tempPassword, username: userName, userPoolId: userPoolId)
        )
        .flatMap { response in
            let sub = response.user!.attributes!.first(where: { $0.name == "sub" })!.value!
            return self.cognito.adminInitiateAuth(
                .init(
                    authFlow: .adminNoSrpAuth,
                    authParameters: [
                        "USERNAME": userName,
                        "PASSWORD": tempPassword,
                    ],
                    clientId: self.clientId, userPoolId: self.userPoolId
                )
            )
            .and(value: sub)
        }
        .flatMap {
            (response: CognitoIdentityProvider.AdminInitiateAuthResponse, sub: String)
                -> EventLoopFuture<
                    (CognitoIdentityProvider.AdminRespondToAuthChallengeResponse, String)
                > in
            let input = CognitoIdentityProvider.AdminRespondToAuthChallengeRequest(
                challengeName: .newPasswordRequired,
                challengeResponses: [
                    "USERNAME": userName,
                    "NEW_PASSWORD": password,
                    "userAttributes.email": email,
                ],
                clientId: self.clientId,
                session: response.session,
                userPoolId: self.userPoolId
            )
            return self.cognito.adminRespondToAuthChallenge(input).and(value: sub)
        }
        .map { response, sub in
            User(token: response.authenticationResult!.idToken!, sub: sub)
        }
    }

    func destroyUser(userName: String) -> EventLoopFuture<Void> {
        cognito.adminDeleteUser(.init(username: userName, userPoolId: userPoolId))
    }
}
