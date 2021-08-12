//
//  Message.swift
//  DomainEntity
//
//  Created by Masato TSUTSUMI on 2021/05/20.
//

import Foundation

public struct MessageRoom: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var name: String?
    public var members: [User]
    public var owner: User
    public var latestMessage: Message?
    
    public init(
        id: MessageRoom.ID, name: String?, members: [User], owner: User, latestMessage: Message?
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.owner = owner
        self.latestMessage = latestMessage
    }
}

public struct Message: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var roomId: MessageRoom.ID
    public var sentBy: User
    public var text: String?
    public var imageUrl: String?
    public var sentAt: Date
    public var readingUsers: [User]
    
    public init(
        id: Message.ID,
        roomId: MessageRoom.ID,
        sentBy: User,
        text: String?,
        imageUrl: String?,
        sentAt: Date,
        readingUsers: [User]
    ) {
        self.id = id
        self.roomId = roomId
        self.sentBy = sentBy
        self.text = text
        self.imageUrl = imageUrl
        self.sentAt = sentAt
        self.readingUsers = readingUsers
    }
}
