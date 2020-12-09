import Foundation

public struct CreateLive: EndpointProtocol {
    public struct Request: Codable {
        public var title: String
        public var style: LiveStyleInput
        public var artworkURL: Foundation.URL?
        public var hostGroupId: Group.ID
        // TODO: liveHouseId
        public var openAt: Date?
        public var startAt: Date?
        public var endAt: Date?

        public init(
            title: String, style: LiveStyleInput, artworkURL: URL?, hostGroupId: Group.ID,
            openAt: Date?, startAt: Date?, endAt: Date?
        ) {
            self.title = title
            self.style = style
            self.artworkURL = artworkURL
            self.hostGroupId = hostGroupId
            self.openAt = openAt
            self.startAt = startAt
            self.endAt = endAt
        }
    }
    public typealias Response = Live
    public struct URI: CodableURL {
        @StaticPath("lives") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct EditLive: EndpointProtocol {
    public struct Request: Codable {
        public var title: String
        public var artworkURL: Foundation.URL?
        // TODO: liveHouseId
        public var openAt: Date?
        public var startAt: Date?
        public var endAt: Date?

        public init(
            title: String, artworkURL: URL?,
            openAt: Date?, startAt: Date?, endAt: Date?
        ) {
            self.title = title
            self.artworkURL = artworkURL
            self.openAt = openAt
            self.startAt = startAt
            self.endAt = endAt
        }
    }
    public typealias Response = Live
    public struct URI: CodableURL {
        @StaticPath("lives", "edit") public var prefix: Void
        @DynamicPath public var id: Live.ID
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct ReplyPerformanceRequest: EndpointProtocol {
    public struct Request: Codable {
        public enum Reply: String, Codable {
            case accept, deny
        }
        public let requestId: PerformanceRequest.ID
        public let reply: Reply
        public init(
            requestId: PerformanceRequest.ID,
            reply: Reply
        ) {
            self.requestId = requestId
            self.reply = reply
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("lives", "reply") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetPerformanceRequests: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<PerformanceRequest>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("lives", "requests") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
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

public struct ReserveTicket: EndpointProtocol {
    public struct Request: Codable {
        public let liveId: Live.ID
        public init(liveId: Live.ID) {
            self.liveId = liveId
        }
    }
    public typealias Response = Ticket
    public struct URI: CodableURL {
        @StaticPath("lives", "reserve") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

