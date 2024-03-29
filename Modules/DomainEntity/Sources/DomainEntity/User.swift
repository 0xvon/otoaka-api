import Foundation

public struct Artist: Codable, Equatable {
    public var part: String
    public init(part: String) {
        self.part = part
    }
}

public struct Fan: Codable, Equatable {
    public init() {}
}

public enum RoleProperties: Codable, Equatable {
    case artist(Artist)
    case fan(Fan)

    enum CodingKeys: CodingKey {
        case kind, value
    }

    enum Kind: String, Codable {
        case artist, fan
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .artist:
            self = try .artist(container.decode(Artist.self, forKey: .value))
        case .fan:
            self = try .fan(container.decode(Fan.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .artist(artist):
            try container.encode(Kind.artist, forKey: .kind)
            try container.encode(artist, forKey: .value)
        case let .fan(fan):
            try container.encode(Kind.fan, forKey: .kind)
            try container.encode(fan, forKey: .value)
        }
    }
}

public struct User: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var name: String
    public var username: String?
    public var biography: String?
    public var sex: String?
    public var age: Int?
    public var liveStyle: String?
    public var residence: String?
    public var thumbnailURL: String?
    public var role: RoleProperties
    public var twitterUrl: URL?
    public var instagramUrl: URL?
    public var point: Int

    public init(
        id: ID, name: String, username: String?, biography: String?, sex: String?, age: Int?,
        liveStyle: String?, residence: String?, thumbnailURL: String?, role: RoleProperties,
        twitterUrl: URL?, instagramUrl: URL?,
        point: Int
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.biography = biography
        self.sex = sex
        self.age = age
        self.liveStyle = liveStyle
        self.residence = residence
        self.thumbnailURL = thumbnailURL
        self.role = role
        self.twitterUrl = twitterUrl
        self.instagramUrl = instagramUrl
        self.point = point
    }
}

public struct UserFeed: Codable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var text: String
    public var feedType: FeedType
    public var author: User
    public var ogpUrl: String?
    public var thumbnailUrl: String?
    public var group: Group
    public var title: String
    public var createdAt: Date

    public init(
        id: UserFeed.ID, text: String, feedType: FeedType, author: User, ogpUrl: String?,
        thumbnailUrl: String?, group: Group, title: String, createdAt: Date
    ) {
        self.id = id
        self.text = text
        self.feedType = feedType
        self.author = author
        self.ogpUrl = ogpUrl
        self.thumbnailUrl = thumbnailUrl
        self.group = group
        self.title = title
        self.createdAt = createdAt
    }
}

public struct UserFeedComment: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var text: String
    public var author: User
    public var userFeedId: UserFeed.ID
    public var createdAt: Date

    public init(
        id: UserFeedComment.ID, text: String, author: User, userFeedId: UserFeed.ID,
        createdAt: Date
    ) {
        self.id = id
        self.text = text
        self.author = author
        self.userFeedId = userFeedId
        self.createdAt = createdAt
    }
}

public struct UserNotification: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var user: User
    public var isRead: Bool
    public var notificationType: UserNotificationType
    public var createdAt: Date

    public init(
        id: ID, user: User, isRead: Bool, notificationType: UserNotificationType, createdAt: Date
    ) {
        self.id = id
        self.user = user
        self.isRead = isRead
        self.notificationType = notificationType
        self.createdAt = createdAt
    }
}

public struct Post: Codable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var author: User
    public var live: Live?
    public var isPrivate: Bool
    public var text: String
    public var tracks: [PostTrack]
    public var groups: [Group]
    public var imageUrls: [String]
    public var createdAt: Date

    public init(
        id: Post.ID,
        author: User,
        live: Live?,
        isPrivate: Bool,
        text: String,
        tracks: [PostTrack],
        groups: [Group],
        imageUrls: [String],
        createdAt: Date
    ) {
        self.id = id
        self.author = author
        self.live = live
        self.isPrivate = isPrivate
        self.text = text
        self.tracks = tracks
        self.groups = groups
        self.imageUrls = imageUrls
        self.createdAt = createdAt
    }
}

public struct PostTrack: Codable, Equatable, Identifiable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var trackName: String
    public var groupName: String
    public var type: FeedType
    public var thumbnailUrl: String?

    public init(
        id: PostTrack.ID, trackName: String, groupName: String, type: FeedType,
        thumbnailUrl: String?
    ) {
        self.id = id
        self.trackName = trackName
        self.groupName = groupName
        self.type = type
        self.thumbnailUrl = thumbnailUrl
    }
}

public struct PostComment: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var text: String
    public var author: User
    public var post: Post
    public var createdAt: Date

    public init(
        id: PostComment.ID, text: String, author: User, post: Post, createdAt: Date
    ) {
        self.id = id
        self.text = text
        self.author = author
        self.post = post
        self.createdAt = createdAt
    }
}

public enum UserNotificationType: Codable, Equatable {
    case follow(User)
    case like(UserFeedLike)
    case comment(UserFeedComment)
    case likePost(PostLike)
    case postComment(PostComment)
    case officialAnnounce(OfficialAnnounce)

    enum CodingKeys: CodingKey {
        case kind, value
    }

    enum Kind: String, Codable {
        case follow, like, likePost, comment, postComment, officialAnnounce
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .follow:
            self = try .follow(container.decode(User.self, forKey: .value))
        case .like:
            self = try .like(container.decode(UserFeedLike.self, forKey: .value))
        case .likePost:
            self = try .likePost(container.decode(PostLike.self, forKey: .value))
        case .comment:
            self = try .comment(container.decode(UserFeedComment.self, forKey: .value))
        case .postComment:
            self = try .postComment(container.decode(PostComment.self, forKey: .value))
        case .officialAnnounce:
            self = try .officialAnnounce(container.decode(OfficialAnnounce.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .follow(followedBy):
            try container.encode(Kind.follow, forKey: .kind)
            try container.encode(followedBy, forKey: .value)
        case let .like(likeUserFeed):
            try container.encode(Kind.like, forKey: .kind)
            try container.encode(likeUserFeed, forKey: .value)
        case let .likePost(postLike):
            try container.encode(Kind.likePost, forKey: .kind)
            try container.encode(postLike, forKey: .value)
        case let .comment(comment):
            try container.encode(Kind.comment, forKey: .kind)
            try container.encode(comment, forKey: .value)
        case let .postComment(comment):
            try container.encode(Kind.postComment, forKey: .kind)
            try container.encode(comment, forKey: .value)
        case let .officialAnnounce(officialAnnounce):
            try container.encode(Kind.officialAnnounce, forKey: .kind)
            try container.encode(officialAnnounce, forKey: .value)
        }
    }
}

public struct OfficialAnnounce: Codable, Equatable {
    public var title: String
    public var url: String?

    public init(title: String, url: String?) {
        self.title = title
        self.url = url
    }
}

public struct UserFeedLike: Codable, Equatable {
    public var feed: UserFeed
    public var likedBy: User

    public init(feed: UserFeed, likedBy: User) {
        self.feed = feed
        self.likedBy = likedBy
    }
}

public struct PostLike: Codable, Equatable {
    public var post: Post
    public var likedBy: User

    public init(post: Post, likedBy: User) {
        self.post = post
        self.likedBy = likedBy
    }
}
