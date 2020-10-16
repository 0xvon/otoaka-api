import NIO

public protocol UserRepository {
    func create(foreignId: User.ForeignID) -> EventLoopFuture<User>
    func find(by foreignId: User.ForeignID) -> EventLoopFuture<User?>
}
