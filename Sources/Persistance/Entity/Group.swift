import Domain
import Fluent
import Foundation

final class Group: Model {
    static let schema = "groups"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "english_name")
    var englishName: String?

    @Field(key: "biography")
    var biography: String?

    @Timestamp(key: "since", on: .none)
    var since: Date?

    @Field(key: "artwork_url")
    var artworkURL: URL?

    @Field(key: "hometown")
    var hometown: String?

    init() {}

    init(
        id: UUID? = nil, name: String, englishName: String?,
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
    }
}

extension Domain.Group: EntityConvertible {
    typealias PersistanceEntity = Group

    init(fromPersistance entity: Group) throws {
        try self.init(
            id: ID(entity.requireID()),
            name: entity.name, englishName: entity.englishName,
            biography: entity.biography, since: entity.since,
            artworkURL: entity.artworkURL, hometown: entity.hometown
        )
    }

    func asPersistance() -> Group {
        Group(id: id.rawValue, name: name, englishName: englishName, biography: biography,
              since: since, artworkURL: artworkURL, hometown: hometown)
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
}

extension Domain.Membership: EntityConvertible {
    typealias PersistanceEntity = Membership

    init(fromPersistance entity: Membership) throws {
        try self.init(
            id: entity.requireID(),
            groupId: entity.$group.id,
            artistId: entity.$artist.id
        )
    }

    func asPersistance() -> Membership {
        let entity = Membership()
        entity.id = id
        entity.$group.id = groupId
        entity.$artist.id = artistId
        return entity
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

    /// Always `nil` when `invited` is false
    @OptionalParent(key: "membership_id")
    var membership: Membership?

    init() {
        invited = false
    }
}

extension Domain.GroupInvitation: EntityConvertible {
    typealias PersistanceEntity = GroupInvitation
    init(fromPersistance entity: GroupInvitation) throws {
        try self.init(
            id: entity.requireID(),
            group: Domain.Group(fromPersistance: entity.group),
            invited: entity.invited,
            membership: nil
        )
    }

    func asPersistance() -> GroupInvitation {
        let entity = GroupInvitation()
        entity.id = id
        entity.$group.id = group.id.rawValue
        entity.invited = invited
        entity.$membership.id = membership?.id
        return entity
    }
}
