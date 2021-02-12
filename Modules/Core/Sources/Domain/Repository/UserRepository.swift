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
    func isExists(by id: User.ID) -> EventLoopFuture<Bool>
    func endpointArns(for id: Domain.User.ID) -> EventLoopFuture<[String]>
    func setEndpointArn(_ endpointArn: String, for id: User.ID) -> EventLoopFuture<Void>
}
