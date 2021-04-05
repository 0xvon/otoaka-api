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
    func feeds(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<UserFeedSummary>>
    func search(query: String, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func getNotifications(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Page<UserNotification>>
    func readNotification(notificationId: UserNotification.ID) -> EventLoopFuture<Void>
}
