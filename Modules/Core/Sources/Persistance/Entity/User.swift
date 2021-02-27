import Domain
import FluentKit
import Foundation

public enum Role: String, Codable {
    case artist
    case fan
}

final class User: Model {
    static var schema: String = "users"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "biography")
    var biography: String?

    @Field(key: "thumbnail_url")
    var thumbnailURL: String?

    @Field(key: "cognito_id")
    var cognitoId: String

    @OptionalField(key: "cognito_username")
    var cognitoUsername: CognitoUsername?

    @Field(key: "email")
    var email: String

    @Enum(key: "role")
    var role: Role

    /// Only for artist.
    @OptionalField(key: "part")
    var part: String?

    init() {}
    init(
        cognitoId: Domain.CognitoID, cognitoUsername: CognitoUsername,
        email: String, name: String,
        biography: String?, thumbnailURL: String?, role: Domain.RoleProperties
    ) {
        self.cognitoId = cognitoId
        self.cognitoUsername = cognitoUsername
        self.email = email
        self.name = name
        self.biography = biography
        self.thumbnailURL = thumbnailURL
        switch role {
        case .artist(let artist):
            self.role = .artist
            part = artist.part
        case .fan:
            self.role = .fan
        }
    }
}

extension Endpoint.User {
    static func translate(fromPersistance entity: User, on db: Database) -> EventLoopFuture<Self> {
        let roleProperties: Endpoint.RoleProperties
        switch entity.role {
        case .artist:
            roleProperties = .artist(Endpoint.Artist(part: entity.part!))
        case .fan:
            roleProperties = .fan(Endpoint.Fan())
        }
        return db.eventLoop.submit {
            try Self.init(
                id: ID(entity.requireID()), name: entity.name, biography: entity.biography,
                thumbnailURL: entity.thumbnailURL, role: roleProperties)
        }
    }
}

final class UserDevice: Model {
    static let schema = "user_devices"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "endpoint_arn")
    var endpointArn: String

    @Parent(key: "user_id")
    var user: User

    init() {}
    init(id: UUID? = nil, endpointArn: String, user: User.IDValue) {
        self.id = id
        self.endpointArn = endpointArn
        self.$user.id = user
    }
}

final class Following: Model {
    static let schema = "followings"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "self_user_id")
    var user: User

    @Parent(key: "target_group_id")
    var target: Group

    init() {}
}

final class UserFollowing: Model {
    static let schema = "user_followings"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "self_user_id")
    var user: User
    
    @Parent(key: "target_user_id")
    var target: User
    
    init() {}
}

final class LiveLike: Model {
    static let schema = "live_likes"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "live_id")
    var live: Live
}

final class UserFeed: Model {
    static let schema: String = "user_feeds"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "text")
    var text: String

    @Enum(key: "feed_type")
    var feedType: FeedType

    @OptionalField(key: "youtube_url")
    var youtubeURL: String?

    @Parent(key: "author_id")
    var author: User
    
    @OptionalField(key: "ogp_url")
    var ogpUrl: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Children(for: \.$feed)
    var comments: [UserFeedComment]
}

extension Endpoint.UserFeed {
    static func translate(fromPersistance entity: UserFeed, on db: Database) -> EventLoopFuture<
        Endpoint.UserFeed
    > {
        let author = entity.$author.get(on: db)
        let feedType: Endpoint.FeedType
        switch entity.feedType {
        case .youtube:
            feedType = .youtube(URL(string: entity.youtubeURL!)!)
        }
        return author.flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
            .flatMapThrowing { author in
                try Endpoint.UserFeed(
                    id: .init(entity.requireID()),
                    text: entity.text, feedType: feedType,
                    author: author, ogpUrl: entity.ogpUrl, createdAt: entity.createdAt!
                )
            }
    }
}

final class UserFeedComment: Model {
    static let schema: String = "user_feed_comments"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "text")
    var text: String

    @Parent(key: "user_feed_id")
    var feed: UserFeed

    @Parent(key: "author_id")
    var author: User

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
}

extension Endpoint.UserFeedComment {
    static func translate(fromPersistance entity: UserFeedComment, on db: Database)
        -> EventLoopFuture<
            Endpoint.UserFeedComment
        >
    {
        let author = entity.$author.get(on: db)
        return author.flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
            .flatMapThrowing { author in
                try Endpoint.UserFeedComment(
                    id: .init(entity.requireID()),
                    text: entity.text, author: author,
                    userFeedId: .init(entity.$feed.id),
                    createdAt: entity.createdAt!
                )
            }
    }
}
