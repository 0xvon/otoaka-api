import Domain
import Fluent
import Foundation

public class GroupRepository: Domain.GroupRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }

    public enum Error: Swift.Error {
        case userNotFound
        case groupNotFound
        case invitationNotFound
    }

    public func create(input: Endpoint.CreateGroup.Request) -> EventLoopFuture<Domain.Group> {
        let group = Group(
            name: input.name, englishName: input.englishName,
            biography: input.biography, since: input.since,
            artworkURL: input.artworkURL, hometown: input.hometown)
        return group.save(on: db).flatMap { [db] in
            Domain.Group.translate(fromPersistance: group, on: db)
        }
    }

    public func joinWithInvitation(invitationId: Domain.GroupInvitation.ID, artist: Domain.User.ID)
        -> EventLoopFuture<Void>
    {
        return db.transaction { db -> EventLoopFuture<Void> in
            let maybeInvitation = GroupInvitation.find(invitationId.rawValue, on: db)
            return maybeInvitation.optionalFlatMap { invitation -> EventLoopFuture<Void> in
                let joined = Self.join(
                    toGroup: Domain.Group.ID(invitation.$group.id), artist: artist, on: db)
                return joined.flatMapThrowing { try $0.requireID() }.flatMap { membershipID in
                    invitation.$membership.id = membershipID
                    invitation.invited = true
                    return invitation.save(on: db)
                }
            }
            .unwrap(orError: Error.invitationNotFound)
        }
    }
    public func join(toGroup groupId: Domain.Group.ID, artist: Domain.User.ID) -> EventLoopFuture<
        Void
    > {
        Self.join(toGroup: groupId, artist: artist, on: db).map { _ in }
    }

    private static func join(
        toGroup groupId: Domain.Group.ID,
        artist: Domain.User.ID, on db: Database
    ) -> EventLoopFuture<Membership> {
        let artist = User.query(on: db)
            .filter(\.$id == artist.rawValue)
            .filter(\.$role == Role.artist)
            .first()
        let group = Group.find(groupId.rawValue, on: db)
        return artist.and(group).flatMapThrowing { (user, group) -> (UUID, UUID) in
            guard let user = user else { throw Error.userNotFound }
            guard let group = group else { throw Error.groupNotFound }
            return try (user.requireID(), group.requireID())
        }
        .flatMap { [db] (userID, groupID) -> EventLoopFuture<Membership> in
            let membership = Membership()
            membership.$artist.id = userID
            membership.$group.id = groupID
            return membership.save(on: db).map { membership }
        }
    }

    public func invite(toGroup groupdId: Domain.Group.ID) -> EventLoopFuture<Domain.GroupInvitation>
    {
        return db.transaction { db in
            let maybeGroup = Group.find(groupdId.rawValue, on: db)
            return maybeGroup.flatMapThrowing { group -> UUID in
                guard let group = group else { throw Error.groupNotFound }
                return try group.requireID()
            }
            .flatMap { [db] groupID -> EventLoopFuture<Domain.GroupInvitation> in
                let invitation = GroupInvitation()
                invitation.$group.id = groupID
                return invitation.save(on: db).flatMap { [db] in
                    Endpoint.GroupInvitation.translate(fromPersistance: invitation, on: db)
                }
            }
        }
    }

    public func findInvitation(by invitationId: Domain.GroupInvitation.ID) -> EventLoopFuture<
        Domain.GroupInvitation?
    > {
        GroupInvitation.find(invitationId.rawValue, on: db)
            .optionalFlatMap { [db] in
                Endpoint.GroupInvitation.translate(fromPersistance: $0, on: db)
            }
    }

    public func isMember(of groupId: Domain.Group.ID, member: Domain.User.ID) -> EventLoopFuture<
        Bool
    > {
        Membership.query(on: db)
            .filter(\.$artist.$id == member.rawValue)
            .filter(\.$group.$id == groupId.rawValue)
            .count().map { $0 > 0 }
    }

    public func findGroup(by id: Domain.Group.ID) -> EventLoopFuture<Domain.Group?> {
        Group.find(id.rawValue, on: db).optionalFlatMap { [db] in
            Endpoint.Group.translate(fromPersistance: $0, on: db)
        }
    }
}
