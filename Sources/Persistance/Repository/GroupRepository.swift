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
    }

    public func create(
        name: String, englishName: String?, biography: String?,
        since: Date?, artworkURL: URL?, hometown: String?
    ) -> EventLoopFuture<Domain.Group> {
        let group = Group(name: name, englishName: englishName,
                          biography: biography, since: since,
                          artworkURL: artworkURL, hometown: hometown)
        return group.save(on: db).flatMapThrowing {
            try Domain.Group(fromPersistance: group)
        }
    }

    public func join(toGroup groupId: Domain.Group.ID, artist: Domain.User.ID) -> EventLoopFuture<Void> {
        let eventLoop = db.eventLoop
        let artist = User.query(on: db)
            .filter(\.$id == artist.rawValue)
            .filter(\.$role == Role.artist)
            .first()
        let group = Group.find(groupId.rawValue, on: db)
        return artist.and(group).flatMap { [db] (user, group) -> EventLoopFuture<Void> in
            guard let user = user else {
                return eventLoop.makeFailedFuture(Error.userNotFound)
            }
            guard let group = group else {
                return eventLoop.makeFailedFuture(Error.groupNotFound)
            }
            let membership = Membership()
            membership.artist = user
            membership.group = group
            return membership.save(on: db)
        }
    }

    public func invite(toGroup groupdId: Domain.Group.ID) -> EventLoopFuture<Domain.GroupInvitation> {
        let eventLoop = db.eventLoop
        let maybeGroup = Group.find(groupdId.rawValue, on: db)
        return maybeGroup.flatMap { [db] group -> EventLoopFuture<Domain.GroupInvitation> in
            guard let group = group else {
                return eventLoop.makeFailedFuture(Error.groupNotFound)
            }
            let invitation = GroupInvitation()
            invitation.group = group
            return invitation.save(on: db).flatMapThrowing {
                try Domain.GroupInvitation(fromPersistance: invitation)
            }
        }
    }

    public func isMember(of groupId: Domain.Group.ID, member: Domain.User.ID) -> EventLoopFuture<Bool> {
        Membership.query(on: db)
            .filter(\.$artist.$id == member.rawValue)
            .filter(\.$group.$id == groupId.rawValue)
            .count().map { $0 > 0 }
    }

    public func isExists(by id: Domain.Group.ID) -> EventLoopFuture<Bool> {
        Group.find(id.rawValue, on: db).map { $0 != nil }
    }
}
