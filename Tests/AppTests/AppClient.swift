import Endpoint
import StubKit
import Vapor

class AppUser {
    private let cognito: CognitoClient
    private let userName: String
    let token: String
    let user: User

    init(userName: String, cognito: CognitoClient, token: String, user: User) {
        self.userName = userName
        self.cognito = cognito
        self.token = token
        self.user = user
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
        makeHeaders(for: user.token)
    }

    func makeHeaders(for token: String) -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .authorization, value: "Bearer \(token)")
        headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
        return headers
    }

    func createUser(
        name: String = UUID().uuidString,
        role: RoleProperties = .artist(Artist(part: "vocal"))
    ) throws -> AppUser {
        let user = try! cognito.createToken(userName: name).wait()
        let headers = makeHeaders(for: user.token)
        let body = Endpoint.Signup.Request(name: name, role: role)
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        var appUser: AppUser!
        try app.test(.POST, "users/signup", headers: headers, body: bodyData) { res in
            let response = try res.content.decode(Signup.Response.self)
            appUser = AppUser(
                userName: name, cognito: cognito,
                token: user.token, user: response
            )
        }
        return appUser
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
        hostGroup: Endpoint.Group, style: LiveStyleInput? = nil,
        with user: AppUser
    ) throws -> Endpoint.Live {
        let style = style ?? .oneman(performer: hostGroup.id)
        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: hostGroup.id)
            $0.set(\.style, value: style)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        var created: Endpoint.Live!
        try app.test(.POST, "lives", headers: makeHeaders(for: user), body: bodyData) {
            res in
            created = try res.content.decode(Endpoint.CreateLive.Response.self)
        }
        return created
    }

    func getPerformanceRequests(page: Int = 1, per: Int = 10, with user: AppUser) throws -> Page<
        PerformanceRequest
    > {
        var response: Page<PerformanceRequest>!
        try app.test(
            .GET, "lives/requests?page=\(page)&per=\(per)", headers: makeHeaders(for: user)
        ) {
            res in
            response = try res.content.decode(Endpoint.GetPerformanceRequests.Response.self)
        }
        return response
    }

    func replyPerformanceRequest(
        request: PerformanceRequest, reply: ReplyPerformanceRequest.Request.Reply,
        with user: AppUser
    ) throws {
        let body = try! Stub.make(Endpoint.ReplyPerformanceRequest.Request.self) {
            $0.set(\.requestId, value: request.id)
            $0.set(\.reply, value: reply)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        try app.test(.POST, "lives/reply", headers: makeHeaders(for: user), body: bodyData)
    }

    func follow(group: Group, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.FollowGroup.Request.self) {
            $0.set(\.id, value: group.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/follow_group", headers: makeHeaders(for: user), body: bodyData)
    }

    func like(live: Live, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.LikeLive.Request.self) {
            $0.set(\.liveId, value: live.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/like_live", headers: makeHeaders(for: user), body: bodyData)
    }

    func createGroupFeed(
        group: Group,
        feedType: FeedType = .youtube(try! Stub.make()),
        with user: AppUser
    ) throws -> GroupFeed {
        let body = try! Stub.make(Endpoint.CreateGroupFeed.Request.self) {
            $0.set(\.groupId, value: group.id)
            $0.set(\.feedType, value: feedType)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        var created: Endpoint.GroupFeed!
        try app.test(.POST, "groups/create_feed", headers: makeHeaders(for: user), body: bodyData) {
            res in
            created = try res.content.decode(Endpoint.CreateGroupFeed.Response.self)
        }
        return created
    }
}
