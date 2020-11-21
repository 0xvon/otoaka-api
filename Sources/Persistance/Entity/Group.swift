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

extension Endpoint.Group {
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
