import Foundation

public struct Group: Codable, Identifiable {
    public typealias ID = Identifier<Self>
    public let id: ID
    public var name: String
    public var englishName: String?
    public var biography: String?
    public var since: Date?
    public var artworkURL: URL?
    public var hometown: String?
    public var isVerified: Bool

    public init(
        id: ID, name: String, englishName: String?,
        biography: String?, since: Date?, artworkURL: URL?,
        hometown: String?
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.biography = biography
        self.since = since
        self.artworkURL = artworkURL
        self.hometown = hometown
        isVerified = false
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

public enum FeedType: Codable {
    case youtube(URL)

    enum CodingKeys: CodingKey {
        case kind, value
    }

    enum Kind: String, Codable {
        case youtube
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .youtube:
            self = try .youtube(container.decode(URL.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .youtube(url):
            try container.encode(Kind.youtube, forKey: .kind)
            try container.encode(url, forKey: .value)
        }
    }
}
public struct GroupFeed: Codable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var text: String
    public var feedType: FeedType
    public var group: Group
    public var createdAt: Date

    public init(id: GroupFeed.ID, text: String, feedType: FeedType, group: Group, createdAt: Date) {
        self.id = id
        self.text = text
        self.feedType = feedType
        self.group = group
        self.createdAt = createdAt
    }
}
