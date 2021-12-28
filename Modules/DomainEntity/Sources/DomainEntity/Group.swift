import Foundation

public struct Group: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public let id: ID
    public var name: String
    public var englishName: String?
    public var biography: String?
    public var since: Date?
    public var artworkURL: URL?
    public var twitterId: String?
    public var youtubeChannelId: String?
    public var hometown: String?
    public var isEntried: Bool

    public init(
        id: ID, name: String, englishName: String?,
        biography: String?, since: Date?, artworkURL: URL?,
        twitterId: String?, youtubeChannelId: String?,
        hometown: String?,
        isEntried: Bool = false
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.biography = biography
        self.since = since
        self.artworkURL = artworkURL
        self.twitterId = twitterId
        self.youtubeChannelId = youtubeChannelId
        self.hometown = hometown
        self.isEntried = isEntried
    }
}

/// User (Artist) <-> Group
public struct Membership: Codable, Identifiable {
    public typealias ID = Identifier<Self>
    public let id: ID
    public var groupId: Group.ID
    public var artistId: User.ID

    public init(id: ID, groupId: Group.ID, artistId: User.ID) {
        self.id = id
        self.groupId = groupId
        self.artistId = artistId
    }
}

public struct GroupInvitation {
    public typealias ID = Identifier<Self>
    public let id: ID
    public var group: Group
    public var invited: Bool
    /// Always `nil` when `invited` is false
    public var membership: Membership?

    public init(id: ID, group: Group, invited: Bool, membership: Membership?) {
        self.id = id
        self.group = group
        self.invited = invited
        self.membership = membership
    }
}

public enum FeedType: Codable, Equatable {
    case youtube(URL)
    case appleMusic(String)

    enum CodingKeys: CodingKey {
        case kind, value
    }

    enum Kind: String, Codable {
        case youtube, appleMusic
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .youtube:
            self = try .youtube(container.decode(URL.self, forKey: .value))
        case .appleMusic:
            self = try .appleMusic(container.decode(String.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .youtube(url):
            try container.encode(Kind.youtube, forKey: .kind)
            try container.encode(url, forKey: .value)
        case let .appleMusic(songId):
            try container.encode(Kind.appleMusic, forKey: .kind)
            try container.encode(songId, forKey: .value)
        }
    }
}
public struct ArtistFeed: Codable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var text: String
    public var thumbnailUrl: String?
    public var feedType: FeedType
    public var author: User
    public var createdAt: Date

    public init(
        id: ArtistFeed.ID, text: String, thumbnailUrl: String?, feedType: FeedType, author: User,
        createdAt: Date
    ) {
        self.id = id
        self.text = text
        self.thumbnailUrl = thumbnailUrl
        self.feedType = feedType
        self.author = author
        self.createdAt = createdAt
    }
}

public struct ArtistFeedComment: Codable {
    public init(
        id: ArtistFeedComment.ID, text: String, author: User, artistFeedId: ArtistFeed.ID,
        createdAt: Date
    ) {
        self.id = id
        self.text = text
        self.author = author
        self.artistFeedId = artistFeedId
        self.createdAt = createdAt
    }

    public typealias ID = Identifier<Self>
    public var id: ID
    public var text: String
    public var author: User
    public var artistFeedId: ArtistFeed.ID
    public var createdAt: Date
}
