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
    
    @OptionalField(key: "twitter_url")
    var twitterUrl: String?
    
    @OptionalField(key: "instagram_url")
    var instagramUrl: String?

    init() {}
    init(
        cognitoId: Domain.CognitoID, cognitoUsername: CognitoUsername,
        email: String, name: String,
        biography: String?, thumbnailURL: String?, role: Domain.RoleProperties, twitterUrl: URL?, instagramUrl: URL?
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
        self.twitterUrl = twitterUrl?.absoluteString
        self.instagramUrl = instagramUrl?.absoluteString
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
                thumbnailURL: entity.thumbnailURL, role: roleProperties, twitterUrl: entity.twitterUrl.flatMap(URL.init(string:)), instagramUrl: entity.instagramUrl.flatMap(URL.init(string:)))
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
    
    @OptionalField(key: "apple_music_song_id")
    var appleMusicSongId: String?

    @Parent(key: "author_id")
    var author: User
    
    @OptionalField(key: "thumbnail_url")
    var thumbnailUrl: String?
    
    @OptionalField(key: "ogp_url")
    var ogpUrl: String?
    
    @Parent(key: "group_id")
    var group: Group
    
    @Field(key: "title")
    var title: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Children(for: \.$feed)
    var comments: [UserFeedComment]
    
    @Children(for: \.$feed)
    var likes: [UserFeedLike]
}

final class UserFeedLike: Model {
    static let schema = "user_feed_likes"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "user_feed_id")
    var feed: UserFeed
}

extension Endpoint.UserFeed {
    static func translate(fromPersistance entity: UserFeed, on db: Database) -> EventLoopFuture<
        Endpoint.UserFeed
    > {
        let eventLoop = db.eventLoop
        let id = eventLoop.submit { try entity.requireID()}
        let author = entity.$author.get(on: db).flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
        let group = entity.$group.get(on: db).flatMap { Endpoint.Group.translate(fromPersistance: $0, on: db) }
        
        let feedType: Endpoint.FeedType
        switch entity.feedType {
        case .youtube:
            feedType = .youtube(URL(string: entity.youtubeURL!)!)
        case .apple_music:
            feedType = .appleMusic(entity.appleMusicSongId!)
        }
        return id.and(author).and(group)
            .map { ($0.0, $0.1, $1) }
            .map {
                Endpoint.UserFeed(id: ID($0), text: entity.text, feedType: feedType, author: $1, ogpUrl: entity.ogpUrl, thumbnailUrl: entity.thumbnailUrl, group: $2, title: entity.title, createdAt: entity.createdAt!)
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

final class Post: Model {
    static let schema: String = "posts"
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "author_id")
    var author: User
    
    @Field(key: "text")
    var text: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Children(for: \.$post)
    var tracks: [PostTrack]
    
    @Children(for: \.$post)
    var groups: [PostGroup]
    
    @Children(for: \.$post)
    var imageUrls: [PostImageUrl]
    
    @Children(for: \.$post)
    var likes: [PostLike]
    
    @Children(for: \.$post)
    var comments: [PostComment]
}

final class PostTrack: Model {
    static let schema: String = "post_tracks"
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "post_id")
    var post: Post
    
    @Field(key: "track_name")
    var trackName: String
    
    @Field(key: "group_name")
    var groupName: String
    
    @Enum(key: "type")
    var type: FeedType
    
    @OptionalField(key: "youtube_url")
    var youtubeURL: String?
    
    @OptionalField(key: "apple_music_song_id")
    var appleMusicSongId: String?
    
    @OptionalField(key: "thumbnail_url")
    var thumbnailUrl: String?
}

final class PostGroup: Model {
    static let schema: String = "post_groups"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "post_id")
    var post: Post
    
    @Parent(key: "group_id")
    var group: Group
}

final class PostImageUrl: Model {
    static let schema: String = "post_image_urls"
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "post_id")
    var post: Post
    
    @Field(key: "image_url")
    var imageUrl: String
    
    @Field(key: "order")
    var order: Int
}

final class PostLike: Model {
    static let schema: String = "post_likes"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "post_id")
    var post: Post
}

final class PostComment: Model {
    static let schema: String = "post_comments"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "text")
    var text: String
    
    @Parent(key: "author_id")
    var author: User
    
    @Parent(key: "post_id")
    var post: Post
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
}

extension Endpoint.Post {
    static func translate(fromPersistance entity: Post, on db: Database) -> EventLoopFuture<Endpoint.Post> {
        let eventLoop = db.eventLoop
        let id = eventLoop.submit { try entity.requireID() }
        let author = entity.$author.get(on: db).flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
        let imageUrls = entity.$imageUrls.get(on: db)
        let tracks = entity.$tracks.get(on: db)
            .flatMapEach(on: eventLoop) { [db] in
            Domain.PostTrack.translate(fromPersistance: $0, on: db)
        }
        let groups = entity.$groups.get(on: db).flatMapEach(on: eventLoop) { [db] in
            $0.$group.get(on: db)
                .flatMap { [db] in
                    Domain.Group.translate(fromPersistance: $0, on: db)
                }
        }
        
        return id.and(author).and(imageUrls).and(tracks).and(groups)
            .map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1, $1) }
            .map {
                Endpoint.Post(
                    id: ID($0),
                    author: $1,
                    text: entity.text,
                    tracks: $3,
                    groups: $4,
                    imageUrls: $2.map { $0.$imageUrl.value! },
                    createdAt: entity.createdAt!
                )
            }
    }
}

extension Endpoint.PostTrack {
    static func translate(fromPersistance entity: PostTrack, on db: Database) -> EventLoopFuture<Endpoint.PostTrack> {
        let eventLoop = db.eventLoop
        let id = eventLoop.submit { try entity.requireID() }
        
        let type: Endpoint.FeedType
        switch entity.type {
        case .youtube:
            type = .youtube(URL(string: entity.youtubeURL!)!)
        case .apple_music:
            type = .appleMusic(entity.appleMusicSongId!)
        }
        
        return id.map { $0 }
            .map {
                Endpoint.PostTrack(id: ID($0), trackName: entity.trackName, groupName: entity.groupName, type: type, thumbnailUrl: entity.thumbnailUrl)
            }
    }
}

extension Endpoint.PostComment {
    static func translate(fromPersistance entity: PostComment, on db: Database) -> EventLoopFuture<Endpoint.PostComment> {
        let author = entity.$author.get(on: db).flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
        let post = entity.$post.get(on: db).flatMap { Endpoint.Post.translate(fromPersistance: $0, on: db) }
        
        return author.and(post)
            .map { ($0, $1) }
            .flatMapThrowing {
                try Endpoint.PostComment(id: .init(entity.requireID()), text: entity.text, author: $0, post: $1, createdAt: entity.createdAt!)
            }
    }
}

public enum UserNotificationType: String, Codable {
    case follow
    case like
    case comment
    case like_post
    case comment_post
    case official_announce
}

final class UserNotification: Model {
    static let schema: String = "user_notifications"
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "is_read")
    var isRead: Bool
    
    @Parent(key: "user_id")
    var user: User
    
    @Enum(key: "notification_type")
    var notificationType: UserNotificationType
    
    @OptionalParent(key: "followed_by_id")
    var followedBy: User?
    
    @OptionalParent(key: "liked_user_id")
    var likedBy: User?
    
    @OptionalParent(key: "liked_feed_id")
    var likedFeed: UserFeed?
    
    @OptionalParent(key: "liked_post_id")
    var likedPost: Post?
    
    @OptionalParent(key: "feed_comment_id")
    var feedComment: UserFeedComment?
    
    @OptionalParent(key: "post_comment_id")
    var postComment: PostComment?
    
    @OptionalField(key: "title")
    var title: String?
    
    @OptionalField(key: "url")
    var url: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    init(
        isRead: Bool, user: User.IDValue, userNotificationType: Endpoint.UserNotificationType
    ) {
        self.isRead = isRead
        self.$user.id = user
        switch userNotificationType {
        case let .follow(followedBy):
            self.notificationType = .follow
            self.$followedBy.id = followedBy.id.rawValue
        case let .like(likeUserFeed):
            self.notificationType = .like
            self.$likedBy.id = likeUserFeed.likedBy.id.rawValue
            self.$likedFeed.id = likeUserFeed.feed.id.rawValue
        case let .likePost(likePost):
            self.notificationType = .like
            self.$likedBy.id = likePost.likedBy.id.rawValue
            self.$likedPost.id = likePost.post.id.rawValue
        case let .comment(comment):
            self.notificationType = .comment
            self.$feedComment.id = comment.id.rawValue
        case let .postComment(comment):
            self.notificationType = .comment
            self.$postComment.id = comment.id.rawValue
        case let .officialAnnounce(announce):
            self.notificationType = .official_announce
            self.title = announce.title
            self.url = announce.url
        }
    }
}

extension Endpoint.UserNotification {
    static func translate(fromPersistance entity: UserNotification, on db: Database) -> EventLoopFuture<Self> {
        let user = entity.$user.get(on: db)
            .flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
        switch entity.notificationType {
        case .follow:
            let followedBy = entity.$followedBy.get(on: db)
                .flatMap { Endpoint.User.translate(fromPersistance: $0!, on: db)}
            return user.and(followedBy).map { ($0, $1) }
                .flatMapThrowing { user, followedBy in
                    return try Endpoint.UserNotification(id: .init(entity.requireID()), user: user, isRead: entity.isRead, notificationType: .follow(followedBy), createdAt: entity.createdAt!)
                }
        case .like:
            let likedBy = entity.$likedBy.get(on: db)
                .flatMap { Endpoint.User.translate(fromPersistance: $0!, on: db) }
            let likedFeed = entity.$likedFeed.get(on: db)
                .flatMap { Endpoint.UserFeed.translate(fromPersistance: $0!, on: db) }
            return user.and(likedBy).and(likedFeed).map { ( $0.0, $0.1, $1 )}
                .flatMapThrowing { user, likedBy, likedFeed in
                    return try Endpoint.UserNotification(id: .init(entity.requireID()), user: user, isRead: entity.isRead, notificationType: .like(Endpoint.UserFeedLike(feed: likedFeed, likedBy: likedBy)), createdAt: entity.createdAt!)
                }
        case .like_post:
            let likedBy = entity.$likedBy.get(on: db)
                .flatMap { Endpoint.User.translate(fromPersistance: $0!, on: db) }
            let likedPost = entity.$likedPost.get(on: db)
                .flatMap { Endpoint.Post.translate(fromPersistance: $0!, on: db) }
            return user.and(likedBy).and(likedPost).map { ( $0.0, $0.1, $1 )}
                .flatMapThrowing { user, likedBy, likedPost in
                    return try Endpoint.UserNotification(id: .init(entity.requireID()), user: user, isRead: entity.isRead, notificationType: .likePost(Endpoint.PostLike(post: likedPost, likedBy: likedBy)), createdAt: entity.createdAt!)
                }
        case .comment:
            let comment = entity.$feedComment.get(on: db)
                .flatMap { Endpoint.UserFeedComment.translate(fromPersistance: $0!, on: db) }
            return user.and(comment).map { ($0, $1) }
                .flatMapThrowing { user, comment in
                    return try Endpoint.UserNotification(id: .init(entity.requireID()), user: user, isRead: entity.isRead, notificationType: .comment(comment), createdAt: entity.createdAt!)
                }
        case .comment_post:
            let comment = entity.$postComment.get(on: db)
                .flatMap { Endpoint.PostComment.translate(fromPersistance: $0!, on: db) }
            return user.and(comment).map { ($0, $1) }
                .flatMapThrowing { user, comment in
                    return try Endpoint.UserNotification(id: .init(entity.requireID()), user: user, isRead: entity.isRead, notificationType: .postComment(comment), createdAt: entity.createdAt!)
                }
        case .official_announce:
            return user.flatMapThrowing { user in
                return try Endpoint.UserNotification(id: .init(entity.requireID()), user: user, isRead: entity.isRead, notificationType: .officialAnnounce(Endpoint.OfficialAnnounce(title: entity.title!, url: entity.url)), createdAt: entity.createdAt!)
            }
        }
    }
}
