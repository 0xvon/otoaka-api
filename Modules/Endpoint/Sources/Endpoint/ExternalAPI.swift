//
//  ExternalAPI.swift
//  App
//
//  Created by Masato TSUTSUMI on 2021/04/25.
//

import Foundation

public struct CreateGroupAsMaster: EndpointProtocol {
    public typealias Request = CreateGroup.Request
    public typealias Response = Group
    public struct URI: CodableURL {
        @StaticPath("external", "create_group") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct BatchGroupUpdates: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("external", "group_updates") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct ListChannel: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = YouTubePage<YouTubeVideo>
    public struct URI: CodableURL, YouTubePaginationQuery {
        @StaticPath("youtube", "v3", "search") public var prefix: Void
        @Query public var channelId: String?
        @Query public var q: String?
        @Query public var part: String
        @Query public var publishedBefore: String?
        @Query public var maxResults: Int
        @Query public var order: String?
        @Query public var type: String?
        @Query public var pageToken: String?
        @Query public var key: String?
        public init() {}
    }
    public static let method: HTTPMethod = .get
}


