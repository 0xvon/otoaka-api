//
//  CreateMessage.swift
//  Persistance
//
//  Created by Masato TSUTSUMI on 2021/05/20.
//

import FluentKit

struct CreateMessageRoom: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(MessageRoom.schema)
            .id()
            .field("name", .string)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(MessageRoom.schema).delete()
    }
}

struct CreateMessageRoomMember: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(MessageRoomMember.schema)
            .id()
            .field("room_id", .uuid, .required)
            .foreignKey("room_id", references: MessageRoom.schema, .id)
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .field("is_owner", .bool, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(MessageRoomMember.schema).delete()
    }
}

struct CreateMessage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Message.schema)
            .id()
            .field("room_id", .uuid, .required)
            .foreignKey("room_id", references: MessageRoom.schema, .id)
            .field("sent_by_id", .uuid, .required)
            .foreignKey("sent_by_id", references: User.schema, .id)
            .field("text", .string)
            .field("image_url", .string)
            .field("sent_at", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Message.schema).delete()
    }
}

struct CreateMessageReading: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(MessageReading.schema)
            .id()
            .field("message_id", .uuid, .required)
            .foreignKey("message_id", references: Message.schema, .id)
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(MessageReading.schema).delete()
    }
}

struct AddMessageRoomToLatestMessageAt: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(MessageRoom.schema)
            .field("latest_message_at", .datetime)
            .update()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(MessageRoom.schema)
            .deleteField("latest_message_at")
            .update()
    }
}
