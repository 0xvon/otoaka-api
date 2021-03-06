import Domain
import FluentKit

public class UserRepository: Domain.UserRepository {
    private let db: Database
    public enum Error: Swift.Error {
        case alreadyCreated
        case userNotFound
        case deviceAlreadyRegistered
        case cantChangeRole
        case feedNotFound
        case feedDeleted
    }

    public init(db: Database) {
        self.db = db
    }

    public func create(cognitoId: CognitoID, cognitoUsername: CognitoUsername, email: String, input: Signup.Request)
        -> EventLoopFuture<Endpoint.User>
    {
        let existing = User.query(on: db).filter(\.$cognitoId == cognitoId).first()
        return existing.guard({ $0 == nil }, else: Error.alreadyCreated)
            .flatMap { [db] _ -> EventLoopFuture<Endpoint.User> in
                let storedUser = User(
                    cognitoId: cognitoId, cognitoUsername: cognitoUsername, email: email,
                    name: input.name, biography: input.biography,
                    thumbnailURL: input.thumbnailURL, role: input.role
                )
                return storedUser.create(on: db).flatMap { [db] in
                    Endpoint.User.translate(fromPersistance: storedUser, on: db)
                }
            }
    }

    public func editInfo(userId: Domain.User.ID, input: EditUserInfo.Request)
        -> EventLoopFuture<Endpoint.User>
    {
        let user = User.find(userId.rawValue, on: db).unwrap(orError: Error.userNotFound)
        return user.flatMapThrowing { user -> User in
            user.name = input.name
            user.biography = input.biography
            user.thumbnailURL = input.thumbnailURL
            switch (user.role, input.role) {
            case (.artist, .artist(let artist)):
                user.part = artist.part
            case (.fan, .fan): break
            default:
                throw Error.cantChangeRole
            }
            return user
        }
        .flatMap { [db] user in
            return user.update(on: db).transform(to: user)
        }
        .flatMap { [db] user in
            Endpoint.User.translate(fromPersistance: user, on: db)
        }
    }

    public func all() -> EventLoopFuture<[Domain.User]> {
        User.query(on: db).all().flatMapEach(on: db.eventLoop) { [db] in
            Domain.User.translate(fromPersistance: $0, on: db)
        }
    }

    public func find(by cognitoId: Domain.CognitoID) -> EventLoopFuture<Endpoint.User?> {
        let maybeUser = User.query(on: db).filter(\.$cognitoId == cognitoId).first()
        return maybeUser.optionalFlatMap { [db] user in
            Endpoint.User.translate(fromPersistance: user, on: db)
        }
    }
    
    public func find(by userId: Domain.User.ID) -> EventLoopFuture<Domain.User?> {
        User.find(userId.rawValue, on: db).optionalFlatMap { [db] in
            Endpoint.User.translate(fromPersistance: $0, on: db)
        }
    }

    public func findByUsername(username: CognitoUsername) -> EventLoopFuture<Domain.User?> {
        let maybeUser = User.query(on: db).filter(\.$cognitoUsername == username).first()
        return maybeUser.optionalFlatMap { [db] user in
            Endpoint.User.translate(fromPersistance: user, on: db)
        }
    }
    public func isExists(by id: Domain.User.ID) -> EventLoopFuture<Bool> {
        User.find(id.rawValue, on: db).map { $0 != nil }
    }

    public func endpointArns(for id: Domain.User.ID) -> EventLoopFuture<[String]> {
        UserDevice.query(on: db).filter(\.$user.$id == id.rawValue).all().map {
            $0.map(\.endpointArn)
        }
    }

    public func setEndpointArn(_ endpointArn: String, for id: Domain.User.ID) -> EventLoopFuture<
        Void
    > {
        let isExisting = UserDevice.query(on: db)
            .filter(\.$user.$id == id.rawValue)
            .filter(\.$endpointArn == endpointArn)
            .first().map { $0 != nil }
        let device = UserDevice(endpointArn: endpointArn, user: id.rawValue)
        let precondition = isExisting.and(isExists(by: id)).flatMapThrowing {
            guard $1 else { throw Error.userNotFound }
            guard !$0 else { throw Error.deviceAlreadyRegistered }
            return
        }
        return precondition.flatMap { [db] in
            device.save(on: db)
        }
    }
    
    public func createFeed(for input: Endpoint.CreateUserFeed.Request, authorId: Domain.User.ID)
        -> EventLoopFuture<Domain.UserFeed>
    {
        let feed = UserFeed()
        feed.text = input.text
        feed.$author.id = authorId.rawValue
        feed.$group.id = input.groupId.rawValue
        feed.ogpUrl = input.ogpUrl
        feed.title = input.title
        switch input.feedType {
        case .youtube(let url):
            feed.feedType = .youtube
            feed.youtubeURL = url.absoluteString
        }
        return feed.create(on: db).flatMap { [db] in
            Domain.UserFeed.translate(fromPersistance: feed, on: db)
        }
    }

    public func deleteFeed(id: Domain.UserFeed.ID) -> EventLoopFuture<Void> {
        _ = UserFeedLike.query(on: db)
            .filter(\.$feed.$id == id.rawValue)
            .all()
            .flatMap { [db] in
                $0.delete(force: true, on: db)
            }
        _ = UserFeedComment.query(on: db)
            .filter(\.$feed.$id == id.rawValue)
            .all()
            .flatMap { [db] in
                $0.delete(force: true, on: db)
            }
        return UserFeed.find(id.rawValue, on: db)
            .unwrap(orError: Error.feedNotFound)
            .flatMapThrowing { feed -> UserFeed in
                guard feed.$id.exists else { throw Error.feedDeleted }
                return feed
            }
            .flatMap { [db] in $0.delete(on: db) }
    }

    public func feeds(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.UserFeedSummary>
    > {
        UserFeed.query(on: db)
            .filter(\UserFeed.$author.$id == userId.rawValue)
            .with(\.$comments)
            .with(\.$likes)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    feed -> EventLoopFuture<UserFeedSummary> in
                    return Domain.UserFeed.translate(fromPersistance: feed, on: db).map {
                        UserFeedSummary(feed: $0, commentCount: feed.comments.count, likeCount: feed.likes.count, isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(userId.rawValue))
                    }
                }
            }
    }

    public func getUserFeed(feedId: Domain.UserFeed.ID) -> EventLoopFuture<Domain.UserFeed> {
        UserFeed.find(feedId.rawValue, on: db).unwrap(orError: Error.feedNotFound)
            .flatMap { [db] in Domain.UserFeed.translate(fromPersistance: $0, on: db) }
    }

    public func addUserFeedComment(userId: Domain.User.ID, input: PostUserFeedComment.Request)
        -> EventLoopFuture<
            Domain.UserFeedComment
        >
    {
        let comment = UserFeedComment()
        comment.$author.id = userId.rawValue
        comment.$feed.id = input.feedId.rawValue
        comment.text = input.text
        return comment.save(on: db).flatMap { [db] in
            Domain.UserFeedComment.translate(fromPersistance: comment, on: db)
        }
    }

    public func getUserFeedComments(feedId: Domain.UserFeed.ID, page: Int, per: Int)
        -> EventLoopFuture<Domain.Page<Domain.UserFeedComment>>
    {
        UserFeedComment.query(on: db)
            .filter(\.$feed.$id == feedId.rawValue)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    Domain.UserFeedComment.translate(fromPersistance: $0, on: db)
                }
            }
    }
    
    public func search(query: String, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.User>
    > {
        let lives = User.query(on: db)
            .group(.or) {
                $0.filter(\.$name =~ query)
                    .filter(\.$biography =~ query)
            }
        return lives.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.User.translate(fromPersistance: $0, on: db)
            }
        }
    }
}
