import Endpoint
import StubKit
import Vapor

class AppUser {
    private let cognito: CognitoClient
    private let userName: String
    let token: String
    init(userName: String, cognito: CognitoClient) {
        self.userName = userName
        self.cognito = cognito
        let user = try! cognito.createToken(userName: userName).wait()
        self.token = user.token
    }
    deinit {
        try! cognito.destroyUser(userName: userName).wait()
    }
}

class AppClient {
    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let app: Application
    private let cognito: CognitoClient
    init(application: Application, cognito: CognitoClient) {
        self.app = application
        self.cognito = cognito
    }

    func makeHeaders(for user: AppUser) -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .authorization, value: "Bearer \(user.token)")
        headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
        return headers
    }

    func createUser(
        name: String = UUID().uuidString,
        role: RoleProperties = .artist(Artist(part: "vocal"))
    ) throws -> AppUser {
        let user = AppUser(userName: UUID().uuidString, cognito: cognito)
        let headers = makeHeaders(for: user)
        let body = Endpoint.Signup.Request(name: name, role: role)
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        try app.test(.POST, "users/signup", headers: headers, body: bodyData)
        return user
    }

    func createGroup(body: CreateGroup.Request = try! Stub.make(), with user: AppUser) throws
        -> Endpoint.Group
    {
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        var createdGroup: Endpoint.Group!
        try app.test(.POST, "groups", headers: makeHeaders(for: user), body: bodyData) { res in
            createdGroup = try res.content.decode(CreateGroup.Response.self)
        }
        return createdGroup
    }

    func createInvitation(group: Endpoint.Group, with user: AppUser) throws
        -> Endpoint.InviteGroup.Invitation
    {
        let body = try! Stub.make(InviteGroup.Request.self) {
            $0.set(\.groupId, value: group.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        var createdInvitation: Endpoint.InviteGroup.Invitation!
        try app.test(.POST, "groups/invite", headers: makeHeaders(for: user), body: bodyData) {
            res in
            createdInvitation = try res.content.decode(InviteGroup.Response.self)
        }
        return createdInvitation
    }

    func createLive(
        hostGroup: Endpoint.Group, performers: [Endpoint.Group] = [], with user: AppUser
    ) throws -> Endpoint.Live {
        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: hostGroup.id)
            $0.set(\.performerGroupIds, value: performers.map(\.id))
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        var created: Endpoint.Live!
        try app.test(.POST, "lives", headers: makeHeaders(for: user), body: bodyData) {
            res in
            created = try res.content.decode(Endpoint.CreateLive.Response.self)
        }
        return created
    }
}
