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
        case notMemberOfGroup
        case feedNotFound
    }

    public func create(input: Endpoint.CreateGroup.Request) -> EventLoopFuture<Domain.Group> {
        let group = Group(
            name: input.name, englishName: input.englishName,
            biography: input.biography, since: input.since,
            artworkURL: input.artworkURL,
            twitterId: input.twitterId, youtubeChannelId: input.youtubeChannelId,
            hometown: input.hometown)
        return group.save(on: db).flatMap { [db] in
            Domain.Group.translate(fromPersistance: group, on: db)
        }
    }

    public func update(id: Domain.Group.ID, input: Endpoint.EditGroup.Request) -> EventLoopFuture<
        Domain.Group
    > {
        let group = Group.find(id.rawValue, on: db).unwrap(or: Error.groupNotFound)
        let modified = group.map { (group) -> Group in
            group.name = input.name
            group.englishName = input.englishName
            group.biography = input.biography
            group.since = input.since
            group.artworkURL = input.artworkURL?.absoluteString
            group.twitterId = input.twitterId
            group.youtubeChannelId = input.youtubeChannelId
            group.hometown = input.hometown
            return group
        }
        .flatMap { [db] group in group.update(on: db).map { group } }
        return modified.flatMap { [db] group in
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
    public func join(toGroup groupId: Domain.Group.ID, artist: Domain.User.ID, asLeader: Bool)
        -> EventLoopFuture<
            Void
        >
    {
        Self.join(toGroup: groupId, artist: artist, asLeader: asLeader, on: db).map { _ in }
    }

    private static func join(
        toGroup groupId: Domain.Group.ID,
        artist: Domain.User.ID, asLeader: Bool = false, on db: Database
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
            membership.isLeader = asLeader
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
    public func isLeader(of groupId: Domain.Group.ID, member: Domain.User.ID) -> EventLoopFuture<
        Bool
    > {
        Membership.query(on: db)
            .filter(\.$artist.$id == member.rawValue)
            .filter(\.$group.$id == groupId.rawValue)
            .first().unwrap(or: Error.notMemberOfGroup)
            .map { $0.isLeader }
    }

    public func findGroup(by id: Domain.Group.ID) -> EventLoopFuture<Domain.Group?> {
        Group.find(id.rawValue, on: db).optionalFlatMap { [db] in
            Endpoint.Group.translate(fromPersistance: $0, on: db)
        }
    }

    public func get(page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.Group>> {
        let groups = Group.query(on: db)
        return groups.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.Group.translate(fromPersistance: $0, on: db)
            }
        }
    }

    public func getMemberships(for artistId: Domain.User.ID) -> EventLoopFuture<[Domain.Group]> {
        let memberships = Group.query(on: db)
            .join(Membership.self, on: \Membership.$group.$id == \Group.$id)
            .filter(Membership.self, \.$artist.$id == artistId.rawValue)
            .all()
        return memberships.flatMap { [db] in
            $0.map { Domain.Group.translate(fromPersistance: $0, on: db) }
                .flatten(on: db.eventLoop)
        }
    }

    public func createFeed(for input: Endpoint.CreateArtistFeed.Request, authorId: Domain.User.ID)
        -> EventLoopFuture<Domain.ArtistFeed>
    {
        let feed = ArtistFeed()
        feed.text = input.text
        feed.$author.id = authorId.rawValue
        switch input.feedType {
        case .youtube(let url):
            feed.feedType = .youtube
            feed.youtubeURL = url.absoluteString
        }
        return feed.create(on: db).flatMap { [db] in
            Domain.ArtistFeed.translate(fromPersistance: feed, on: db)
        }
    }

    public func feeds(groupId: Domain.Group.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.ArtistFeedSummary>
    > {
        ArtistFeed.query(on: db)
            .join(Membership.self, on: \Membership.$artist.$id == \ArtistFeed.$author.$id)
            .filter(Membership.self, \Membership.$group.$id == groupId.rawValue)
            .with(\.$comments)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    feed -> EventLoopFuture<ArtistFeedSummary> in
                    return Domain.ArtistFeed.translate(fromPersistance: feed, on: db).map {
                        ArtistFeedSummary(feed: $0, commentCount: feed.comments.count)
                    }
                }
            }
    }

    public func getArtistFeed(feedId: Domain.ArtistFeed.ID) -> EventLoopFuture<Domain.ArtistFeed> {
        ArtistFeed.find(feedId.rawValue, on: db).unwrap(orError: Error.feedNotFound)
            .flatMap { [db] in Domain.ArtistFeed.translate(fromPersistance: $0, on: db) }
    }

    public func addArtistFeedComment(userId: Domain.User.ID, input: PostFeedComment.Request)
        -> EventLoopFuture<
            Domain.ArtistFeedComment
        >
    {
        let comment = ArtistFeedComment()
        comment.$author.id = userId.rawValue
        comment.$feed.id = input.feedId.rawValue
        comment.text = input.text
        return comment.save(on: db).flatMap { [db] in
            Domain.ArtistFeedComment.translate(fromPersistance: comment, on: db)
        }
    }

    public func getArtistFeedComments(feedId: Domain.ArtistFeed.ID, page: Int, per: Int)
        -> EventLoopFuture<Domain.Page<Domain.ArtistFeedComment>>
    {
        ArtistFeedComment.query(on: db)
            .filter(\.$feed.$id == feedId.rawValue)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    Domain.ArtistFeedComment.translate(fromPersistance: $0, on: db)
                }
            }
    }

    public func search(query: String, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.Group>
    > {
        let lives = Group.query(on: db).filter(\.$name =~ query)
        return lives.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.Group.translate(fromPersistance: $0, on: db)
            }
        }
    }
}
