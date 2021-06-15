//
//  Message.swift
//  Persistance
//
//  Created by Masato TSUTSUMI on 2021/05/20.
//

import Domain
import FluentKit
import Foundation

final class MessageRoom: Model {
    static var schema: String = "message_rooms"
    
    @ID(key: .id)
    var id: UUID?
    
    @OptionalField(key: "name")
    var name: String?
    
    @Children(for: \.$room)
    var members: [MessageRoomMember]
    
    @Children(for: \.$room)
    var messages: [Message]
}

final class MessageRoomMember: Model {
    static var schema: String = "message_room_members"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "room_id")
    var room: MessageRoom
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "is_owner")
    var isOwner: Bool
}

final class Message: Model {
    static var schema: String = "messages"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "room_id")
    var room: MessageRoom
    
    @Parent(key: "sent_by_id")
    var sentBy: User
    
    @OptionalField(key: "text")
    var text: String?
    
    @OptionalField(key: "image_url")
    var imageUrl: String?
    
    @Timestamp(key: "sent_at", on: .create)
    var sentAt: Date?
    
    @Children(for: \.$message)
    var readings: [MessageReading]
}

final class MessageReading: Model {
    static var schema: String = "message_readings"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "message_id")
    var message: Message
    
    @Parent(key: "user_id")
    var user: User
}

extension Endpoint.MessageRoom {
    static func translate(fromPersistence entity: MessageRoom, on db: Database) -> EventLoopFuture<Endpoint.MessageRoom> {
        let owner = MessageRoomMember.query(on: db)
            .filter(\.$room.$id == entity.id!)
            .filter(\.$isOwner, .equal, true)
            .first()
            .flatMap { [db] member -> EventLoopFuture<User> in
                return member!.$user.get(on: db)
            }
            .flatMap { [db] user in
                Domain.User.translate(fromPersistance: user, on: db)
            }
        let latestMessage = Message.query(on: db)
            .filter(\.$room.$id == entity.id!)
            .sort(\.$sentAt, .descending)
            .first()
            .optionalFlatMap { Endpoint.Message.translate(fromPersistence: $0, on: db) }
        let members = entity.$members.query(on: db).all().flatMapEach(on: db.eventLoop) { member -> EventLoopFuture<User> in
            return member.$user.get(on: db)
        }
        .flatMapEach(on: db.eventLoop) { [db] user in
            Domain.User.translate(fromPersistance: user, on: db)
        }
        
        return owner.and(latestMessage).and(members)
            .map { ($0.0, $0.1, $1) }
            .flatMapThrowing { owner, latestMessage, members in
                try Endpoint.MessageRoom(
                    id: .init(entity.requireID()),
                    name: entity.name,
                    members: members.filter { $0.id != owner.id },
                    owner: owner,
                    latestMessage: latestMessage
                )
            }
    }
}

extension Endpoint.Message {
    static func translate(fromPersistence entity: Message, on db: Database) -> EventLoopFuture<Endpoint.Message> {
        let readingUsers = MessageReading.query(on: db)
            .filter(\.$message.$id == entity.id!)
            .all()
            .flatMapEach(on: db.eventLoop) { [db] reading -> EventLoopFuture<User> in return reading.$user.get(on: db) }
            .flatMapEach(on: db.eventLoop) { [db] user in Endpoint.User.translate(fromPersistance: user, on: db)}
        let sentBy = entity.$sentBy.get(on: db).flatMap { Endpoint.User.translate(fromPersistance: $0, on: db) }
        
        return readingUsers
            .and(sentBy)
            .map { ($0, $1) }
            .flatMapThrowing {
                try Endpoint.Message(
                    id: .init(entity.requireID()),
                    roomId: .init(entity.$room.id),
                    sentBy: $1,
                    text: entity.text,
                    imageUrl: entity.imageUrl,
                    sentAt: entity.sentAt!,
                    readingUsers: $0
                )
            }
    }
}
