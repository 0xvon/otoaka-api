import Foundation

public struct Group {
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
public struct Membership {
    public let id: UUID
    public var groupId: UUID
    public var artistId: UUID

    public init(id: UUID, groupId: UUID, artistId: UUID) {
        self.id = id
        self.groupId = groupId
        self.artistId = artistId
    }
}

public struct GroupInvitation {
    public let id: UUID
    public var group: Group
    public var invited: Bool
    /// Always `nil` when `invited` is false
    public var membership: Membership?

    public init(id: UUID, group: Group, invited: Bool, membership: Membership?) {
        self.id = id
        self.group = group
        self.invited = invited
        self.membership = membership
    }
}
