import Domain
import Fluent
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
    var artworkURL: URL?

    @OptionalField(key: "hometown")
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

    static func translate(fromPersistance entity: Group, on db: Database) -> EventLoopFuture<Self> {
        db.eventLoop.makeSucceededFuture(entity).flatMapThrowing {
            try ($0, $0.requireID())
        }
        .map { entity, id in
            Self.init(
                id: ID(id),
                name: entity.name, englishName: entity.englishName,
                biography: entity.biography, since: entity.since,
                artworkURL: entity.artworkURL, hometown: entity.hometown
            )
        }
    }

    func asPersistance() -> Group {
        Group(
            id: id.rawValue, name: name, englishName: englishName, biography: biography,
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

    static func translate(fromPersistance entity: Membership, on db: Database) -> EventLoopFuture<
        Self
    > {
        db.eventLoop.makeSucceededFuture(entity).flatMapThrowing {
            try ($0, $0.requireID())
        }
        .map { entity, id in
            Self.init(
                id: id,
                groupId: entity.$group.id,
                artistId: entity.$artist.id
            )
        }
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
    static func translate(fromPersistance entity: GroupInvitation, on db: Database)
        -> EventLoopFuture<Domain.GroupInvitation>
    {
        let group = entity.$group.get(on: db)
        return group.flatMap { Domain.Group.translate(fromPersistance: $0, on: db) }
            .flatMapThrowing { group in
                try Domain.GroupInvitation.init(
                    id: ID(entity.requireID()),
                    group: group,
                    invited: entity.invited,
                    membership: nil
                )
            }
    }

    func asPersistance() -> GroupInvitation {
        let entity = GroupInvitation()
        entity.id = id.rawValue
        entity.$group.id = group.id.rawValue
        entity.invited = invited
        entity.$membership.id = membership?.id
        return entity
    }
}
