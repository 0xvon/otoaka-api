import Endpoint
import StubKit
import Vapor

class AppUser {
    private let authClient: Auth0Client
    private let userName: String
    let token: String
    let user: User

    init(userName: String, authClient: Auth0Client, token: String, user: User) {
        self.userName = userName
        self.authClient = authClient
        self.token = token
        self.user = user
    }
    deinit {
        try! authClient.destroyUser(id: "auth0|\(userName)").wait()
    }
}

class AppClient {
    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let app: Application
    private let authClient: Auth0Client
    init(application: Application, authClient: Auth0Client) {
        self.app = application
        self.authClient = authClient
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
        let user = try! authClient.createToken(userName: name)
        let headers = makeHeaders(for: user.token)
        let body = Endpoint.Signup.Request(
            name: name,
            biography: try! Stub.make(),
            sex: try! Stub.make(),
            age: try! Stub.make(),
            liveStyle: try! Stub.make(),
            residence: try! Stub.make(),
            thumbnailURL: try! Stub.make(),
            role: role,
            twitterUrl: try! Stub.make(),
            instagramUrl: try! Stub.make()
        )
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        var appUser: AppUser!
        try app.test(.POST, "users/signup", headers: headers, body: bodyData) { res in
            let response = try res.content.decode(Signup.Response.self)
            appUser = AppUser(
                userName: name, authClient: authClient,
                token: user.token, user: response
            )
        }
        return appUser
    }

    func createGroup(
        body: CreateGroup.Request = try! Stub.make { $0.set(\.name, value: "WALL OF DEATH") },
        with user: AppUser
    ) throws
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
        with user: AppUser,
        date: String = "20330101",
        liveHouse: String = "somewhere_\(UUID.init().uuidString)"
    ) throws -> Endpoint.Live {
        let host = try createGroup(with: user)
        let battleStyle: LiveStyleInput = .battle(performers: [host.id, hostGroup.id])
        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.title, value: "DEAD POP FESTiVAL 2021")
            $0.set(\.hostGroupId, value: (style != nil) ? hostGroup.id : host.id)
            $0.set(\.date, value: date)
            $0.set(\.liveHouse, value: liveHouse)
            $0.set(\.style, value: style ?? battleStyle)
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

    func updateRecentlyFollowing(groups: [Group.ID], with user: AppUser) throws {
        let body = Endpoint.UpdateRecentlyFollowing.Request(groups: groups)
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/update_recently_following", headers: makeHeaders(for: user),
            body: bodyData)
    }

    func followUser(target: AppUser, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.FollowUser.Request.self) {
            $0.set(\.id, value: target.user.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/follow_user", headers: makeHeaders(for: user), body: bodyData)
    }

    func unfollowUser(target: AppUser, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.UnfollowUser.Request.self) {
            $0.set(\.id, value: target.user.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/unfollow_user", headers: makeHeaders(for: user), body: bodyData)
    }

    func blockUser(target: AppUser, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.BlockUser.Request.self) {
            $0.set(\.id, value: target.user.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/block_user", headers: makeHeaders(for: user), body: bodyData)
    }

    func unblockUser(target: AppUser, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.UnblockUser.Request.self) {
            $0.set(\.id, value: target.user.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/unblock_user", headers: makeHeaders(for: user), body: bodyData)
    }

    func like(live: Live, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.LikeLive.Request.self) {
            $0.set(\.liveId, value: live.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/like_live", headers: makeHeaders(for: user), body: bodyData)
    }

    func unlike(live: Live, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.UnlikeLive.Request.self) {
            $0.set(\.liveId, value: live.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/unlike_live", headers: makeHeaders(for: user), body: bodyData)
    }

    func createArtistFeed(
        feedType: FeedType = .youtube(try! Stub.make()),
        with user: AppUser
    ) throws -> ArtistFeed {
        let body = try! Stub.make(Endpoint.CreateArtistFeed.Request.self) {
            $0.set(\.feedType, value: feedType)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        var created: Endpoint.ArtistFeed!
        try app.test(.POST, "groups/create_feed", headers: makeHeaders(for: user), body: bodyData) {
            res in
            created = try res.content.decode(Endpoint.CreateArtistFeed.Response.self)
        }
        return created
    }

    func createUserFeed(
        feedType: FeedType = .appleMusic(try! Stub.make()),
        with user: AppUser,
        groupId: Group.ID
    ) throws -> UserFeed {
        let body = try! Stub.make(Endpoint.CreateUserFeed.Request.self) {
            $0.set(\.feedType, value: feedType)
            $0.set(\.groupId, value: groupId)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        var created: Endpoint.UserFeed!
        try app.test(.POST, "users/create_feed", headers: makeHeaders(for: user), body: bodyData) {
            res in
            created = try res.content.decode(Endpoint.CreateUserFeed.Response.self)
        }
        return created
    }

    func deleteUserFeed(feed: UserFeed, with user: AppUser) throws {
        let body = try! Stub.make(DeleteUserFeed.Request.self) {
            $0.set(\.id, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        try app.test(.DELETE, "users/delete_feed", headers: makeHeaders(for: user), body: bodyData)
    }

    func likeUserFeed(feed: UserFeed, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.LikeUserFeed.Request.self) {
            $0.set(\.feedId, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/like_user_feed", headers: makeHeaders(for: user), body: bodyData)
    }

    func unlikeUserFeed(feed: UserFeed, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.UnlikeUserFeed.Request.self) {
            $0.set(\.feedId, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/unlike_user_feed", headers: makeHeaders(for: user), body: bodyData)
    }

    func commentUserFeed(feed: UserFeed, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.PostUserFeedComment.Request.self) {
            $0.set(\.feedId, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/user_feed_comment", headers: makeHeaders(for: user), body: bodyData)
    }

    func unlike(feed: UserFeed, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.UnlikeUserFeed.Request.self) {
            $0.set(\.feedId, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/unlike_user_feed", headers: makeHeaders(for: user), body: bodyData)
    }

    func createPost(with user: AppUser, live: Live? = nil) throws -> Post {
        let groupX = try self.createGroup(with: user)
        let groupY = try self.createGroup(with: user)
        let dummyLive = try self.createLive(hostGroup: groupX, with: user)
        let body = try! Stub.make(Endpoint.CreatePost.Request.self) {
            $0.set(\.author, value: user.user.id)
            $0.set(\.groups, value: [groupX, groupY])
            $0.set(\.imageUrls, value: ["something", "something2"])
            $0.set(\.tracks, value: [try! Stub.make(Endpoint.Track.self)])
            $0.set(\.live, value: live?.id ?? dummyLive.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        var created: Endpoint.Post!
        try app.test(.POST, "users/create_post", headers: makeHeaders(for: user), body: bodyData) {
            res in
            created = try res.content.decode(Endpoint.CreatePost.Response.self)
        }
        return created
    }

    func createPost(with user: AppUser, groups: [Group], live: Live? = nil) throws -> Post {
        let dummyLive = try self.createLive(hostGroup: groups.first!, with: user)
        let body = try! Stub.make(Endpoint.CreatePost.Request.self) {
            $0.set(\.author, value: user.user.id)
            $0.set(\.groups, value: groups)
            $0.set(\.imageUrls, value: ["something", "something2"])
            $0.set(\.tracks, value: [try! Stub.make(Endpoint.Track.self)])
            $0.set(\.live, value: live?.id ?? dummyLive.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        var created: Endpoint.Post!
        try app.test(.POST, "users/create_post", headers: makeHeaders(for: user), body: bodyData) {
            res in
            created = try res.content.decode(Endpoint.CreatePost.Response.self)
        }
        return created
    }

    func editPost(with user: AppUser, post: Post) throws -> Post {
        let body = try! Stub.make(Endpoint.EditPost.Request.self) {
            $0.set(\.text, value: "Edited Post")
            $0.set(\.imageUrls, value: ["something3", "something4"])
            $0.set(\.tracks, value: [try! Stub.make(Endpoint.Track.self)])
            $0.set(\.live, value: post.live!.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        var created: Endpoint.Post!
        try app.test(
            .POST, "users/edit_post/\(post.id)", headers: makeHeaders(for: user), body: bodyData
        ) { res in
            created = try res.content.decode(Endpoint.CreatePost.Response.self)
        }
        return created
    }

    func deletePost(postId: Post.ID, with user: AppUser) throws {
        let body = try! Stub.make(DeletePost.Request.self) {
            $0.set(\.postId, value: postId)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(.DELETE, "users/delete_post", headers: makeHeaders(for: user), body: bodyData)
    }

    func likePost(post: Post, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.LikePost.Request.self) {
            $0.set(\.postId, value: post.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/like_post", headers: makeHeaders(for: user), body: bodyData)
    }

    func unlikePost(post: Post, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.UnlikePost.Request.self) {
            $0.set(\.postId, value: post.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/unlike_post", headers: makeHeaders(for: user), body: bodyData)
    }

    func commentPost(post: Post, with user: AppUser) throws {
        let body = try! Stub.make(Endpoint.AddPostComment.Request.self) {
            $0.set(\.postId, value: post.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))

        try app.test(
            .POST, "user_social/add_post_comment", headers: makeHeaders(for: user), body: bodyData)
    }

    func createMessageRoom(with user: AppUser, member: [AppUser]) throws -> MessageRoom {
        let body = try! Stub.make(Endpoint.CreateMessageRoom.Request.self) {
            $0.set(\.members, value: member.map { $0.user.id })
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        var created: Endpoint.MessageRoom!
        try app.test(
            .POST, "messages/create_room", headers: makeHeaders(for: user), body: bodyData
        ) { res in
            created = try res.content.decode(Endpoint.CreateMessageRoom.Response.self)
        }
        return created
    }

    func sendMessage(with user: AppUser, roomId: MessageRoom.ID) throws -> Message {
        let body = try! Stub.make(Endpoint.SendMessage.Request.self) {
            $0.set(\.roomId, value: roomId)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        var created: Endpoint.Message!
        try app.test(
            .POST, "messages", headers: makeHeaders(for: user), body: bodyData
        ) { res in
            created = try res.content.decode(Endpoint.SendMessage.Response.self)
        }
        return created
    }

    func getRooms(page: Int = 1, per: Int = 10, with user: AppUser) throws -> [MessageRoom] {
        var rooms: [MessageRoom] = []
        try app.test(
            .GET, "messages/rooms?page=\(page)&per=\(per)", headers: makeHeaders(for: user)
        ) { res in
            rooms = try res.content.decode(Endpoint.GetRooms.Response.self).items
        }
        return rooms
    }

    func openMessageRoom(page: Int = 1, per: Int = 10, with user: AppUser, roomId: MessageRoom.ID)
        throws -> [Message]
    {
        var messages: [Message] = []
        try app.test(
            .GET, "messages/\(roomId)?page=\(page)&per=\(per)", headers: makeHeaders(for: user)
        ) { res in
            messages = try res.content.decode(Endpoint.OpenRoomMessages.Response.self).items
        }
        return messages
    }

    func deleteMessageRoom(with user: AppUser, roomId: MessageRoom.ID) throws {
        let body = Endpoint.DeleteMessageRoom.Request(roomId: roomId)
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        try app.test(
            .DELETE, "messages/delete_room", headers: makeHeaders(for: user), body: bodyData
        )
    }
}
