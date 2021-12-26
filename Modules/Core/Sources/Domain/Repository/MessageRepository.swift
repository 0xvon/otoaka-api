import Endpoint
import NIO

public protocol MessageRepository {
    func createRoom(selfUser: User.ID, input: CreateMessageRoom.Request) -> EventLoopFuture<
        MessageRoom
    >
    func deleteRoom(selfUser: User.ID, roomId: MessageRoom.ID) -> EventLoopFuture<Void>
    func rooms(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<MessageRoom>>
    func open(selfUser: User.ID, roomId: MessageRoom.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<Message>
    >
    func send(selfUser: User.ID, input: SendMessage.Request) -> EventLoopFuture<Message>
    func getRoomMember(selfUser: User.ID, roomId: MessageRoom.ID) -> EventLoopFuture<[User]>
}
