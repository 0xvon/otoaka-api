import NIO

public protocol UserRepository {
    func create(
        cognitoId: CognitoID, cognitoUsername: CognitoUsername, email: String, input: Signup.Request
    ) -> EventLoopFuture<Domain.User>
    func editInfo(userId: Domain.User.ID, input: EditUserInfo.Request)
        -> EventLoopFuture<Domain.User>

    @available(*, deprecated)
    func find(by foreignId: CognitoID) -> EventLoopFuture<User?>
    func findByUsername(username: CognitoUsername) -> EventLoopFuture<User?>
    func find(by userId: User.ID) -> EventLoopFuture<User?>
    func isExists(by id: User.ID) -> EventLoopFuture<Bool>
    func endpointArns(for id: Domain.User.ID) -> EventLoopFuture<[String]>
    func setEndpointArn(_ endpointArn: String, for id: User.ID) -> EventLoopFuture<Void>
    func createFeed(for input: CreateUserFeed.Request, authorId: User.ID) -> EventLoopFuture<
        UserFeed
    >
    func deleteFeed(id: UserFeed.ID) -> EventLoopFuture<Void>
    func getUserFeed(feedId: Domain.UserFeed.ID) -> EventLoopFuture<Domain.UserFeed>
    func addUserFeedComment(userId: User.ID, input: PostUserFeedComment.Request) -> EventLoopFuture<
        UserFeedComment
    >
    func getUserFeedComments(feedId: UserFeed.ID, page: Int, per: Int)
        -> EventLoopFuture<Page<UserFeedComment>>
    func findUserFeedSummary(userFeedId: UserFeed.ID, userId: User.ID) -> EventLoopFuture<UserFeedSummary?>
    func feeds(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<UserFeedSummary>>
    func createPost(for input: CreatePost.Request, authorId: User.ID) -> EventLoopFuture<Post>
    func editPost(for input: Domain.CreatePost.Request, postId: Domain.Post.ID) -> EventLoopFuture<Domain.Post>
    func deletePost(postId: Post.ID) -> EventLoopFuture<Void>
    func getPost(postId: Domain.Post.ID) -> EventLoopFuture<Domain.Post>
    func findPostSummary(postId: Post.ID, userId: User.ID) -> EventLoopFuture<PostSummary>
    func posts(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<PostSummary>>
    func addPostComment(userId: User.ID, input: AddPostComment.Request) -> EventLoopFuture<
        PostComment
    >
    func getPostComments(postId: Post.ID, page: Int, per: Int)
        -> EventLoopFuture<Page<PostComment>>
    func search(query: String, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func getNotifications(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Page<UserNotification>>
    func readNotification(notificationId: UserNotification.ID) -> EventLoopFuture<Void>
    func all() -> EventLoopFuture<[Domain.User]>
}
