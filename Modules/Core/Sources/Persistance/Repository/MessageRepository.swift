import Domain
import FluentKit
import Foundation

public class MessageRepository: Domain.MessageRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }

    public enum Error: Swift.Error {
        case alreadyCreated
        case alreadyDeleted
        case roomNotFound
        case userNotFound
        case messageNotFound
    }

    public func createRoom(selfUser: Domain.User.ID, input: Domain.CreateMessageRoom.Request)
        -> EventLoopFuture<Domain.MessageRoom>
    {
        MessageRoomMember.query(on: db)
            .join(
                MessageRoomPartner.self,
                on: \MessageRoomMember.$room.$id == \MessageRoomPartner.$room.$id
            )
            .filter(MessageRoomMember.self, \.$user.$id == input.members[0].rawValue)
            .filter(MessageRoomPartner.self, \.$user.$id == selfUser.rawValue)
            .first()
            .flatMap { [db] existing -> EventLoopFuture<Domain.MessageRoom> in
                if let existing = existing {  // return existing room
                    return existing.$room.query(on: db).first()
                        .flatMap { [db] in
                            Domain.MessageRoom.translate(fromPersistence: $0!, on: db)
                        }
                } else {
                    let room = MessageRoom()
                    room.name = input.name
                    let created = room.create(on: db)

                    return created.flatMap { [db] in
                        input.members.forEach { member in
                            let roomMember = MessageRoomMember()
                            roomMember.$room.id = room.id!
                            roomMember.$user.id = member.rawValue
                            roomMember.isOwner = false
                            _ = roomMember.save(on: db)
                        }
                        let roomMaster = MessageRoomMember()
                        roomMaster.$room.id = room.id!
                        roomMaster.$user.id = selfUser.rawValue
                        roomMaster.isOwner = true
                        _ = roomMaster.create(on: db)

                        return Endpoint.MessageRoom.translate(fromPersistence: room, on: db)
                    }
                }
            }
    }

    public func deleteRoom(selfUser: Domain.User.ID, roomId: Domain.MessageRoom.ID)
        -> EventLoopFuture<Void>
    {
        let deletedRoomMember = MessageRoomMember.query(on: db)
            .filter(\.$room.$id == roomId.rawValue)
            .all()
            .flatMap { [db] in $0.delete(force: true, on: db) }
        let messages = Message.query(on: db)
            .filter(\.$room.$id == roomId.rawValue)
            .all()
        let deleted = messages.flatMapEach(on: db.eventLoop) { [db] message in
            MessageReading.query(on: db)
                .filter(\.$message.$id == message.id!)
                .all()
                .flatMap { [db] reading in reading.delete(force: true, on: db) }
        }
        .flatMap { _ in messages }
        .flatMap { [db] in $0.delete(force: true, on: db) }

        return deletedRoomMember.and(deleted)
            .flatMap { [db] _ in
                MessageRoom
                    .find(roomId.rawValue, on: db)
                    .unwrap(orError: Error.roomNotFound)
                    .flatMapThrowing { room -> MessageRoom in
                        guard room.$id.exists else { throw Error.alreadyDeleted }
                        return room
                    }
                    .flatMap { [db] in $0.delete(force: true, on: db) }
            }
    }

    public func rooms(selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.MessageRoom>
    > {
        MessageRoom.query(on: db)
            .join(MessageRoomMember.self, on: \MessageRoomMember.$room.$id == \MessageRoom.$id)
            .filter(MessageRoomMember.self, \.$user.$id == selfUser.rawValue)
            .filter(\.$latestMessageAt != nil)
            .with(\.$members)
            .with(\.$messages)
            .sort(\.$latestMessageAt, .descending)
            .fields(for: MessageRoom.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    room -> EventLoopFuture<Domain.MessageRoom> in
                    return Domain.MessageRoom.translate(fromPersistence: room, on: db)
                }
            }

    }

    public func open(selfUser: Domain.User.ID, roomId: Domain.MessageRoom.ID, page: Int, per: Int)
        -> EventLoopFuture<Domain.Page<Domain.Message>>
    {
        let reading = Message.query(on: db)
            .filter(\.$room.$id == roomId.rawValue)
            .with(\.$readings)
            .all()
            .flatMapEachCompact(on: db.eventLoop) { [db] message -> EventLoopFuture<Message?> in
                message.$readings.query(on: db)
                    .filter(\.$user.$id == selfUser.rawValue)
                    .first()
                    .map { $0 == nil ? message : nil }
            }
            .flatMapEach(on: db.eventLoop) { [db] message -> EventLoopFuture<MessageReading> in
                let new = MessageReading()
                new.$user.id = selfUser.rawValue
                new.$message.id = message.id!
                return new.create(on: db)
                    .map { new }
            }

        return reading.flatMap { [db] _ -> EventLoopFuture<Domain.Page<Domain.Message>> in
            return Message.query(on: db)
                .filter(\.$room.$id == roomId.rawValue)
                .with(\.$readings)
                .sort(\.$sentAt, .descending)
                .paginate(PageRequest(page: page, per: per))
                .flatMap { [db] in
                    Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                        message -> EventLoopFuture<Domain.Message> in
                        Domain.Message.translate(fromPersistence: message, on: db)
                    }
                }
        }
    }

    public func send(selfUser: Domain.User.ID, input: Domain.SendMessage.Request)
        -> EventLoopFuture<Domain.Message>
    {
        let message = Message()
        message.$room.id = input.roomId.rawValue
        message.imageUrl = input.imageUrl
        message.text = input.text
        message.$sentBy.id = selfUser.rawValue
        let created = message.create(on: db)

        let room = MessageRoom.find(input.roomId.rawValue, on: db).unwrap(
            orError: Error.roomNotFound
        ).flatMapThrowing { room -> MessageRoom in
            room.latestMessageAt = Date()
            return room
        }
        .flatMap { [db] room in
            return room.update(on: db).transform(to: room)
        }

        let messageReading = MessageReading()
        messageReading.$message.id = message.id!
        messageReading.$user.id = selfUser.rawValue
        _ = messageReading.create(on: db)

        return created.and(room)
            .flatMap { [db] _ in
                Domain.Message.translate(fromPersistence: message, on: db)
            }
    }

    public func read(selfUser: Domain.User.ID, roomId: Domain.MessageRoom.ID) -> EventLoopFuture<
        Void
    > {
        Message.query(on: db)
            .filter(\.$room.$id == roomId.rawValue)
            .with(\.$readings)
            .all()
            .flatMapEachCompact(on: db.eventLoop) { [db] message -> EventLoopFuture<Message?> in
                message.$readings.query(on: db)
                    .filter(\.$user.$id == selfUser.rawValue)
                    .first()
                    .map { $0 == nil ? message : nil }
            }
            .flatMapEach(on: db.eventLoop) { [db] message -> EventLoopFuture<Void> in
                let new = MessageReading()
                new.$user.id = selfUser.rawValue
                new.$message.id = message.id!
                return new.create(on: db)
            }
            .flatMapThrowing { _ in return }
    }

    public func getRoomMember(selfUser: Domain.User.ID, roomId: Domain.MessageRoom.ID)
        -> EventLoopFuture<[Domain.User]>
    {
        return MessageRoomMember.query(on: db)
            .filter(\.$room.$id == selfUser.rawValue)
            .all()
            .flatMapEach(on: db.eventLoop) { [db] member in
                return Domain.User.translate(fromPersistance: member.user, on: db)
            }
            .flatMapThrowing { $0.filter { $0.id != selfUser } }
    }
}
