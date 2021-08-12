//
//  MessageAPI.swift
//  Endpoint
//
//  Created by Masato TSUTSUMI on 2021/05/20.
//

import Foundation
import CodableURL

public struct CreateMessageRoom: EndpointProtocol {
    public struct Request: Codable {
        public let members: [User.ID]
        public let name: String?
        
        public init(members: [User.ID], name: String?) {
            self.members = members
            self.name = name
        }
    }
    public typealias Response = MessageRoom
    public struct URI: CodableURL {
        @StaticPath("messages", "create_room") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct DeleteMessageRoom: EndpointProtocol {    
    public struct Request: Codable {
        public let roomId: MessageRoom.ID
        
        public init(roomId: MessageRoom.ID) {
            self.roomId = roomId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("messages", "delete_room") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .delete
}

public struct GetRooms: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<MessageRoom>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("messages", "rooms") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct OpenRoomMessages: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<Message>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("messages") public var prefix: Void
        @DynamicPath public var roomId: MessageRoom.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct SendMessage: EndpointProtocol {
    public struct Request: Codable {
        public let roomId: MessageRoom.ID
        public let text: String?
        public let imageUrl: String?
        
        public init(
            roomId: MessageRoom.ID, text: String? = nil, imageUrl: String? = nil
        ) {
            self.roomId = roomId
            self.text = text
            self.imageUrl = imageUrl
        }
    }
    public typealias Response = Message
    public struct URI: CodableURL {
        @StaticPath("messages") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}
