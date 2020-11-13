import NIO

public protocol UserRepository {
    func create(
        cognitoId: CognitoID, email: String, input: Signup.Request
    ) -> EventLoopFuture<Domain.User>
    func find(by foreignId: CognitoID) -> EventLoopFuture<User?>
    func isExists(by id: User.ID) -> EventLoopFuture<Bool>
}
