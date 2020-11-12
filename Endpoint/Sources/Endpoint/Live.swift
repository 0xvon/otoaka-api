import Foundation

public enum LiveStyle: String, Codable {
    case oneman
    case battle
    case festival
}

public struct Live: Codable {
    public let id: String
    public var title: String
    public var style: LiveStyle
    public var artworkURL: URL?
    public var hostGroup: Group
    public var author: User
    // TODO: liveHouseId
    public var startAt: Date?
    public var endAt: Date?
    public var performers: [Group]

    public init(
        id: String, title: String,
        style: LiveStyle, artworkURL: URL?,
        author: User, hostGroup: Group,
        startAt: Date?, endAt: Date?,
        performers: [Group]
    ) {
        self.id = id
        self.title = title
        self.style = style
        self.artworkURL = artworkURL
        self.author = author
        self.hostGroup = hostGroup
        self.startAt = startAt
        self.endAt = endAt
        self.performers = performers
    }
    
}


public struct CreateLive: EndpointProtocol {
    public struct Request: Codable {
        public var title: String
        public var style: LiveStyle
        public var artworkURL: Foundation.URL?
        public var hostGroupId: String
        // TODO: liveHouseId
        public var openAt: Date?
        public var startAt: Date?
        public var endAt: Date?
        public var performerGroupIds: [String]
        
        public init(title: String, style: LiveStyle, artworkURL: Foundation.URL?, hostGroupId: String,
                    openAt: Date?, startAt: Date?, endAt: Date?, performerGroupIds: [String]) {
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
        @DynamicPath public var liveId: String
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public enum TicketStatus: String, Codable {
    case registered, paid, joined
}

public struct Ticket: Codable {
    public var id: String
    public var status: TicketStatus
    public var live: Live
    public var user: User
    
    public init(id: String, status: TicketStatus, live: Live, user: User) {
        self.id = id
        self.status = status
        self.live = live
        self.user = user
    }
}

public struct RegisterLive: EndpointProtocol {
    public struct Request: Codable {
        public let liveId: String
        public init(liveId: String) {
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
