import Domain
import FluentKit
import Foundation

final class Group: Model {
    static let schema = "groups"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "english_name")
    var englishName: String?

    @OptionalField(key: "biography")
    var biography: String?

    @Timestamp(key: "since", on: .none)
    var since: Date?

    @OptionalField(key: "artwork_url")
    var artworkURL: String?

    @OptionalField(key: "twitter_id")
    var twitterId: String?

    @OptionalField(key: "youtube_channel_id")
    var youtubeChannelId: String?

    @OptionalField(key: "hometown")
    var hometown: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    init() {}

    init(
        id: UUID? = nil, name: String, englishName: String?,
        biography: String?, since: Date?, artworkURL: URL?,
        twitterId: String?, youtubeChannelId: String?,
        hometown: String?
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.biography = biography
        self.since = since
        self.artworkURL = artworkURL?.absoluteString
        self.twitterId = twitterId
        self.youtubeChannelId = youtubeChannelId
        self.hometown = hometown
    }
}

extension Endpoint.Group {
    static func translate(fromPersistance entity: Group, on db: Database) -> EventLoopFuture<Self> {
        let isEntried = GroupEntry.query(on: db).filter(\.$group.$id == entity.id!).first().map { $0 != nil }
        return db.eventLoop.makeSucceededFuture(entity).and(isEntried).flatMapThrowing {
            try ($0, $0.requireID(), $1)
        }
        .map { entity, id, isEntried in
            Self.init(
                id: ID(id),
                name: entity.name, englishName: entity.englishName,
                biography: entity.biography, since: entity.since,
                artworkURL: entity.artworkURL.flatMap(URL.init(string:)),
                twitterId: entity.twitterId,
                youtubeChannelId: entity.youtubeChannelId,
                hometown: entity.hometown,
                isEntried: isEntried
            )
        }
    }
}

final class Membership: Model {
    static let schema = "memberships"
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "group_id")
    var group: Group

    @Parent(key: "artist_id")
    var artist: User

    @Field(key: "is_leader")
    var isLeader: Bool
}

extension Endpoint.Membership {
    static func translate(fromPersistance entity: Membership, on db: Database) -> EventLoopFuture<
        Self
    > {
        db.eventLoop.makeSucceededFuture(entity).flatMapThrowing {
            try ($0, $0.requireID())
        }
        .map { entity, id in
            Self.init(
                id: ID(id),
                groupId: Endpoint.Group.ID(entity.$group.id),
                artistId: Endpoint.User.ID(entity.$artist.id)
            )
        }
    }
}

final class GroupEntry: Model {
    static let schema = "group_entries"
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "group_id")
    var group: Group
    
    @Timestamp(key: "entried_at", on: .create)
    var entriedAt: Date?
    
    init() {}
    
    init(
        id: UUID? = nil, groupId: UUID
    ) {
        self.id = id
        self.$group.id = groupId
    }
}

final class GroupInvitation: Model {
    static let schema = "group_invitations"
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "group_id")
    var group: Group

    @Field(key: "invited")
    var invited: Bool

    /// Always `nil` when `invited` is false.
    @OptionalParent(key: "membership_id")
    var membership: Membership?

    init() {
        invited = false
    }
}

extension Endpoint.GroupInvitation {
    static func translate(fromPersistance entity: GroupInvitation, on db: Database)
        -> EventLoopFuture<Endpoint.GroupInvitation>
    {
        let group = entity.$group.get(on: db)
        return group.flatMap { Endpoint.Group.translate(fromPersistance: $0, on: db) }
            .flatMapThrowing { group in
                try Endpoint.GroupInvitation.init(
                    id: ID(entity.requireID()),
                    group: group,
                    invited: entity.invited,
                    membership: nil
                )
            }
    }
}

enum FeedType: String, Codable {
    case youtube
    case apple_music
}

final class ArtistFeed: Model {
    static let schema: String = "artist_feeds"
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

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Children(for: \.$feed)
    var comments: [ArtistFeedComment]
}

extension Endpoint.ArtistFeed {
    static func translate(fromPersistance entity: ArtistFeed, on db: Database) -> EventLoopFuture<
        Endpoint.ArtistFeed
    > {
        let author = entity.$author.get(on: db)
        let feedType: Endpoint.FeedType
        switch entity.feedType {
        case .youtube:
            feedType = .youtube(URL(string: entity.youtubeURL!)!)
        case .apple_music:
            feedType = .appleMusic(entity.appleMusicSongId!)
        }
        return author.flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
            .flatMapThrowing { author in
                try Endpoint.ArtistFeed(
                    id: .init(entity.requireID()),
                    text: entity.text, thumbnailUrl: entity.thumbnailUrl, feedType: feedType,
                    author: author, createdAt: entity.createdAt!
                )
            }
    }
}

final class ArtistFeedComment: Model {
    static let schema: String = "artist_feed_comments"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "text")
    var text: String

    @Parent(key: "artist_feed_id")
    var feed: ArtistFeed

    @Parent(key: "author_id")
    var author: User

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
}

extension Endpoint.ArtistFeedComment {
    static func translate(fromPersistance entity: ArtistFeedComment, on db: Database)
        -> EventLoopFuture<
            Endpoint.ArtistFeedComment
        >
    {
        let author = entity.$author.get(on: db)
        return author.flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
            .flatMapThrowing { author in
                try Endpoint.ArtistFeedComment(
                    id: .init(entity.requireID()),
                    text: entity.text, author: author,
                    artistFeedId: .init(entity.$feed.id),
                    createdAt: entity.createdAt!
                )
            }
    }
}

extension Endpoint.GroupFeed {
    static func translate(fromPersistance entity: Group, selfUser: Domain.User.ID, on db: Database)
        -> EventLoopFuture<Endpoint.GroupFeed>
    {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter
        }()

        let isFollowing = Following.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == entity.id!)
            .count().map { $0 > 0 }
        let followersCount = Following.query(on: db)
            .filter(\.$target.$id == entity.id!)
            .count()
        let watchingCount = LivePerformer.query(on: db)
            .filter(\.$group.$id == entity.id!)
            .join(LiveLike.self, on: \LiveLike.$live.$id == \LivePerformer.$live.$id)
            .join(Live.self, on: \Live.$id == \LivePerformer.$live.$id)
            .filter(Live.self, \.$date < dateFormatter.string(from: Date()))
            .filter(LiveLike.self, \.$user.$id == selfUser.rawValue)
            .count()
        return Domain.Group.translate(fromPersistance: entity, on: db)
            .and(isFollowing)
            .and(followersCount)
            .and(watchingCount)
            .map {
                (
                    $0.0.0,
                    $0.0.1,
                    $0.1,
                    $1
                )
            }
            .map {
                Domain.GroupFeed(
                    group: $0,
                    isFollowing: $1,
                    followersCount: $2,
                    watchingCount: $3
                )
            }
    }
}
