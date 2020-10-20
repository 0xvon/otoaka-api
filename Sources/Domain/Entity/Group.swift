import Foundation

public struct Group {
    public let id: UUID
    public var name: String
    public var englishName: String?
    public var biography: String?
    public var since: Date?
    public var artworkURL: URL?
    public var hometown: String?
    public var isVerified: Bool

    public init(
        id: UUID, name: String, englishName: String?,
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
}

public struct GroupInvitation {
    public let id: UUID
    public var groupId: UUID
    public var invited: Bool
    /// Always `nil` when `invited` is false
    public var membershipId: UUID?
}
