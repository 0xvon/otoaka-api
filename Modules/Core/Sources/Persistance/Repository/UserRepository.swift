import Domain
import FluentKit

public class UserRepository: Domain.UserRepository {
    private let db: Database
    public enum Error: Swift.Error {
        case alreadyCreated
        case userNotFound
        case userNotificationNotFound
        case userNotificationAlreadyRead
        case deviceAlreadyRegistered
        case cantChangeRole
        case feedNotFound
        case feedDeleted
        case postNotFound
        case postDeleted
    }

    public init(db: Database) {
        self.db = db
    }

    public func create(
        cognitoId: CognitoID, cognitoUsername: CognitoUsername, email: String, input: Signup.Request
    )
        -> EventLoopFuture<Endpoint.User>
    {
        let existing = User.query(on: db).filter(\.$cognitoId == cognitoId).first()
        return existing.guard({ $0 == nil }, else: Error.alreadyCreated)
            .flatMap { [db] _ -> EventLoopFuture<Endpoint.User> in
                let storedUser = User(
                    cognitoId: cognitoId,
                    cognitoUsername: cognitoUsername,
                    email: email,
                    name: input.name,
                    biography: input.biography,
                    sex: input.sex,
                    age: input.age,
                    liveStyle: input.liveStyle,
                    residence: input.residence,
                    thumbnailURL: input.thumbnailURL,
                    role: input.role,
                    twitterUrl: input.twitterUrl,
                    instagramUrl: input.instagramUrl
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
            user.sex = input.sex
            user.age = input.age
            user.liveStyle = input.liveStyle
            user.residence = input.residence
            user.thumbnailURL = input.thumbnailURL
            user.twitterUrl = input.twitterUrl?.absoluteString
            user.instagramUrl = input.instagramUrl?.absoluteString
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
        feed.thumbnailUrl = input.thumbnailUrl
        feed.title = input.title
        switch input.feedType {
        case .youtube(let url):
            feed.feedType = .youtube
            feed.youtubeURL = url.absoluteString
        case .appleMusic(let songId):
            feed.feedType = .apple_music
            feed.appleMusicSongId = songId
        }
        return feed.create(on: db).flatMap { [db] in
            Domain.UserFeed.translate(fromPersistance: feed, on: db)
        }
    }

    public func deleteFeed(id: Domain.UserFeed.ID) -> EventLoopFuture<Void> {
        let comments = UserFeedComment.query(on: db)
            .filter(\.$feed.$id == id.rawValue)
            .all()
        let deleteComments = comments.flatMapEach(on: db.eventLoop) { [db] in
            UserNotification.query(on: db)
                .filter(\.$feedComment.$id == $0.id)
                .all()
                .flatMap { [db] in $0.delete(force: true, on: db) }
        }
        .flatMap { [db] in
            comments.flatMap { [db] in $0.delete(force: true, on: db) }
        }
        let deleteLikes = UserNotification.query(on: db)
            .filter(\.$likedFeed.$id == id.rawValue)
            .all()
            .flatMap { [db] in $0.delete(force: true, on: db) }
            .flatMap { [db] in
                UserFeedLike.query(on: db)
                    .filter(\.$feed.$id == id.rawValue)
                    .all()
                    .flatMap { [db] in
                        $0.delete(force: true, on: db)
                    }
            }
        return deleteLikes.and(deleteComments)
            .flatMap { [db] _ in
                UserFeed.find(id.rawValue, on: db)
                    .unwrap(orError: Error.feedNotFound)
                    .flatMapThrowing { feed -> UserFeed in
                        guard feed.$id.exists else { throw Error.feedDeleted }
                        return feed
                    }
                    .flatMap { [db] in $0.delete(on: db) }
            }
    }

    public func feeds(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.UserFeedSummary>
    > {
        UserFeed.query(on: db)
            .filter(\UserFeed.$author.$id == userId.rawValue)
            .with(\.$comments)
            .with(\.$likes)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    feed -> EventLoopFuture<UserFeedSummary> in
                    return Domain.UserFeed.translate(fromPersistance: feed, on: db).map {
                        UserFeedSummary(
                            feed: $0, commentCount: feed.comments.count,
                            likeCount: feed.likes.count,
                            isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(
                                userId.rawValue))
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
        .flatMap { [db] comment in
            let feed = UserFeed.find(input.feedId.rawValue, on: db).unwrap(
                orError: Error.feedNotFound)
            return feed.flatMapThrowing { feed -> UserNotification in
                let notification = UserNotification()
                notification.$feedComment.id = comment.id.rawValue
                notification.$user.id = feed.$author.id
                notification.isRead = false
                notification.notificationType = .comment
                return notification
            }
            .flatMap { [db] in $0.save(on: db) }
            .map { comment }
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

    public func findUserFeedSummary(userFeedId: Domain.UserFeed.ID, userId: Domain.User.ID)
        -> EventLoopFuture<Domain.UserFeedSummary?>
    {
        UserFeed.query(on: db)
            .filter(\.$id == userFeedId.rawValue)
            .with(\.$comments)
            .with(\.$likes)
            .first()
            .optionalFlatMap { [db] feed in
                return Domain.UserFeed.translate(fromPersistance: feed, on: db).map {
                    return UserFeedSummary(
                        feed: $0, commentCount: feed.comments.count, likeCount: feed.likes.count,
                        isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(
                            userId.rawValue))
                }
            }
    }

    public func createPost(for input: Domain.CreatePost.Request, authorId: Domain.User.ID)
        -> EventLoopFuture<Domain.Post>
    {
        let post = Post()
        post.$author.id = input.author.rawValue
        post.$live.id = input.live.rawValue
        post.isPrivate = input.isPrivate
        post.text = input.text

        let created = post.create(on: db)
        for (index, track) in input.tracks.enumerated() {
            let postTrack = PostTrack()
            postTrack.$post.id = post.id!
            postTrack.trackName = track.name
            postTrack.groupName = track.artistName
            postTrack.thumbnailUrl = track.artwork
            postTrack.order = index
            switch track.trackType {
            case .youtube(let url):
                postTrack.type = .youtube
                postTrack.youtubeURL = url.absoluteString
            case .appleMusic(let songId):
                postTrack.type = .apple_music
                postTrack.appleMusicSongId = songId
            }
            _ = postTrack.create(on: db)
        }
        for (index, group) in input.groups.enumerated() {
            let postGroup = PostGroup()
            postGroup.$group.id = group.id.rawValue
            postGroup.$post.id = post.id!
            postGroup.order = index
            _ = postGroup.create(on: db)
        }
        for (index, imageUrl) in input.imageUrls.enumerated() {
            let postImageUrl = PostImageUrl()
            postImageUrl.$post.id = post.id!
            postImageUrl.imageUrl = imageUrl
            postImageUrl.order = index
            _ = postImageUrl.create(on: db)
        }

        return created.flatMap { [db] in
            Domain.Post.translate(fromPersistance: post, on: db)
        }
    }

    public func editPost(for input: Domain.CreatePost.Request, postId: Domain.Post.ID)
        -> EventLoopFuture<Domain.Post>
    {
        let post = Post.find(postId.rawValue, on: db).unwrap(orError: Error.postNotFound)
        let modified = post.map { (post) -> Post in
            post.$live.id = input.live.rawValue
            post.isPrivate = input.isPrivate
            post.text = input.text
            return post
        }
        .flatMap { [db] post in
            post.update(on: db).map { post }
        }

        let trackDeleted = PostTrack.query(on: db).filter(\.$post.$id == postId.rawValue).all()
            .flatMap { [db] in $0.delete(force: true, on: db) }
        let imageUrlDeleted = PostImageUrl.query(on: db).filter(\.$post.$id == postId.rawValue)
            .all().flatMap { [db] in $0.delete(force: true, on: db) }

        for (index, track) in input.tracks.enumerated() {
            let postTrack = PostTrack()
            postTrack.$post.id = postId.rawValue
            postTrack.trackName = track.name
            postTrack.groupName = track.artistName
            postTrack.thumbnailUrl = track.artwork
            postTrack.order = index
            switch track.trackType {
            case .youtube(let url):
                postTrack.type = .youtube
                postTrack.youtubeURL = url.absoluteString
            case .appleMusic(let songId):
                postTrack.type = .apple_music
                postTrack.appleMusicSongId = songId
            }
            _ = postTrack.create(on: db)
        }
        for (index, group) in input.groups.enumerated() {
            let postGroup = PostGroup()
            postGroup.$group.id = group.id.rawValue
            postGroup.$post.id = postId.rawValue
            postGroup.order = index
            _ = postGroup.create(on: db)
        }
        for (index, imageUrl) in input.imageUrls.enumerated() {
            let postImageUrl = PostImageUrl()
            postImageUrl.$post.id = postId.rawValue
            postImageUrl.imageUrl = imageUrl
            postImageUrl.order = index
            _ = postImageUrl.create(on: db)
        }

        return
            modified
            .and(trackDeleted)
            .and(imageUrlDeleted)
            .flatMap { [db] in
                Domain.Post.translate(fromPersistance: $0.0.0, on: db)
            }
    }

    public func deletePost(postId: Domain.Post.ID) -> EventLoopFuture<Void> {
        let postLikeDeleted = UserNotification.query(on: db)
            .filter(\.$likedPost.$id == postId.rawValue)
            .all()
            .flatMap { [db] in $0.delete(force: true, on: db) }
            .flatMap { [db] in
                PostLike.query(on: db)
                    .filter(\.$post.$id == postId.rawValue).all()
                    .flatMap { [db] in $0.delete(force: true, on: db) }
            }
        let commentDeleted = PostComment.query(on: db)
            .filter(\.$post.$id == postId.rawValue).all().flatMapEach(on: db.eventLoop) {
                [db] comment in
                UserNotification.query(on: db)
                    .filter(\.$postComment.$id == comment.id)
                    .all()
                    .flatMap { [db] in $0.delete(force: true, on: db) }
                    .flatMap { [db] in comment.delete(force: true, on: db) }
            }
        let postTrackDeleted = PostTrack.query(on: db)
            .filter(\.$post.$id == postId.rawValue).all()
            .flatMap { [db] in $0.delete(force: true, on: db) }
        let postGroupDeleted = PostGroup.query(on: db)
            .filter(\.$post.$id == postId.rawValue).all()
            .flatMap { [db] in $0.delete(force: true, on: db) }
        let postImageUrlDeleted = PostImageUrl.query(on: db)
            .filter(\.$post.$id == postId.rawValue).all()
            .flatMap { [db] in $0.delete(force: true, on: db) }

        return postLikeDeleted.and(commentDeleted).and(postTrackDeleted).and(postGroupDeleted).and(
            postImageUrlDeleted
        )
        .flatMap { [db] _ in
            Post.find(postId.rawValue, on: db)
                .unwrap(orError: Error.postNotFound)
                .flatMapThrowing { post -> Post in
                    guard post.$id.exists else { throw Error.postDeleted }
                    return post
                }
                .flatMap { [db] in $0.delete(force: true, on: db) }
        }
    }

    public func getPost(postId: Domain.Post.ID) -> EventLoopFuture<Domain.Post> {
        Post.find(postId.rawValue, on: db).unwrap(orError: Error.postNotFound)
            .flatMap { [db] in Domain.Post.translate(fromPersistance: $0, on: db) }
    }

    public func findPostSummary(postId: Domain.Post.ID, userId: Domain.User.ID) -> EventLoopFuture<
        Domain.PostSummary
    > {
        Post.query(on: db)
            .filter(\.$id == postId.rawValue)
            .with(\.$comments)
            .with(\.$likes)
            .with(\.$imageUrls)
            .with(\.$tracks)
            .first()
            .unwrap(orError: Error.postNotFound)
            .flatMap { [db] post in
                return Domain.Post.translate(fromPersistance: post, on: db)
                    .map {
                        return Domain.PostSummary(
                            post: $0,
                            commentCount: post.comments.count,
                            likeCount: post.likes.count,
                            isLiked: post.likes.map { like in like.$user.$id.value! }.contains(
                                userId.rawValue)
                        )
                    }
            }
    }

    public func posts(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.PostSummary>
    > {
        Post.query(on: db)
            .filter(\.$author.$id == userId.rawValue)
            .with(\.$comments)
            .with(\.$likes)
            .with(\.$imageUrls)
            .with(\.$tracks)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) { post in
                    return Domain.Post.translate(fromPersistance: post, on: db)
                        .map {
                            return Domain.PostSummary(
                                post: $0, commentCount: post.comments.count,
                                likeCount: post.likes.count,
                                isLiked: post.likes.map { like in like.$user.$id.value! }.contains(
                                    userId.rawValue))
                        }
                }
            }
    }

    public func addPostComment(userId: Domain.User.ID, input: Domain.AddPostComment.Request)
        -> EventLoopFuture<Domain.PostComment>
    {
        let comment = PostComment()
        comment.$author.id = userId.rawValue
        comment.$post.id = input.postId.rawValue
        comment.text = input.text
        return comment.save(on: db).flatMap { [db] in
            Domain.PostComment.translate(fromPersistance: comment, on: db)
        }
        .flatMap { [db] comment in
            let post = Post.find(input.postId.rawValue, on: db).unwrap(orError: Error.feedNotFound)
            return post.flatMapThrowing { post -> UserNotification? in
                if post.$author.id == userId.rawValue {
                    return nil
                }
                let notification = UserNotification()
                notification.$postComment.id = comment.id.rawValue
                notification.$user.id = post.$author.id
                notification.isRead = false
                notification.notificationType = .comment_post
                return notification
            }
            .optionalFlatMap { [db] in $0.save(on: db) }
            .map { _ in comment }
        }
    }

    public func getPostComments(postId: Domain.Post.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.PostComment>
    > {
        PostComment.query(on: db)
            .filter(\.$post.$id == postId.rawValue)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    Domain.PostComment.translate(fromPersistance: $0, on: db)
                }
            }
    }

    public func search(query: String, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.User>
    > {
        let users = User.query(on: db)
            .join(Username.self, on: \User.$id == \Username.$user.$id, method: .left)
            .group(.or) {
                $0.filter(\.$name, .custom("LIKE"), "%\(query)%")
                    .filter(\.$biography, .custom("LIKE"), "%\(query)%")
                    .filter(Username.self, \.$username, .custom("LIKE"), "%\(query)%")
            }
        return users.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.User.translate(fromPersistance: $0, on: db)
            }
        }
    }

    public func getNotifications(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.UserNotification>
    > {
        UserNotification.query(on: db)
            .filter(\.$user.$id == userId.rawValue)
            .sort(\.$createdAt, .descending)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    Domain.UserNotification.translate(fromPersistance: $0, on: db)
                }
            }
    }

    public func readNotification(notificationId: Domain.UserNotification.ID) -> EventLoopFuture<
        Void
    > {
        let notification = UserNotification.find(notificationId.rawValue, on: db).unwrap(
            orError: Error.userNotificationNotFound)
        return notification.flatMapThrowing { notification -> UserNotification in
            if notification.isRead {
                throw Error.userNotificationAlreadyRead
            } else {
                notification.isRead = true
            }
            return notification
        }
        .flatMap { [db] in $0.update(on: db) }
    }
}
