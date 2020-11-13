import Foundation

public struct CreateLive: EndpointProtocol {
    public struct Request: Codable {
        public var title: String
        public var style: LiveStyle
        public var artworkURL: Foundation.URL?
        public var hostGroupId: Group.ID
        // TODO: liveHouseId
        public var openAt: Date?
        public var startAt: Date?
        public var endAt: Date?
        public var performerGroupIds: [Group.ID]
        
        public init(title: String, style: LiveStyle, artworkURL: URL?, hostGroupId: Group.ID,
                    openAt: Date?, startAt: Date?, endAt: Date?, performerGroupIds: [Group.ID]) {
            self.title = title
            self.style = style
            self.artworkURL = artworkURL
            self.hostGroupId = hostGroupId
            self.openAt = openAt
            self.startAt = startAt
            self.endAt = endAt
            self.performerGroupIds = performerGroupIds
        }
    }
    public typealias Response = Live
    public struct URI: CodableURL {
        @StaticPath("lives") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetLive: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Live
    public struct URI: CodableURL {
        @StaticPath("lives") public var prefix: Void
        @DynamicPath public var liveId: Live.ID
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct RegisterLive: EndpointProtocol {
    public struct Request: Codable {
        public let liveId: Live.ID
        public init(liveId: Live.ID) {
            self.liveId = liveId
        }
    }
    public typealias Response = Ticket
    public struct URI: CodableURL {
        @StaticPath("lives", "register") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetUpcomingLives: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<Live>
    public struct URI: CodableURL {
        @StaticPath("lives", "upcoming") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}
