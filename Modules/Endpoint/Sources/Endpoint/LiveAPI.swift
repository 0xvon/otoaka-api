import Foundation

public struct CreateLive: EndpointProtocol {
    public struct Request: Codable {
        public var title: String
        public var style: LiveStyleInput
        public var price: Int
        public var artworkURL: Foundation.URL?
        public var hostGroupId: Group.ID
        public var liveHouse: String?
        public var date: String?
        public var endDate: String?
        public var openAt: String?
        public var startAt: String?
        public var piaEventCode: String?
        public var piaReleaseUrl: URL?
        public var piaEventUrl: URL?

        public init(
            title: String, style: LiveStyleInput, price: Int, artworkURL: URL?,
            hostGroupId: Group.ID, liveHouse: String?,
            date: String?, endDate: String?, openAt: String?, startAt: String?,
            piaEventCode: String?, piaReleaseUrl: URL?, piaEventUrl: URL?
        ) {
            self.title = title
            self.style = style
            self.price = price
            self.artworkURL = artworkURL
            self.hostGroupId = hostGroupId
            self.liveHouse = liveHouse
            self.date = date
            self.endDate = endDate
            self.openAt = openAt
            self.startAt = startAt
            self.piaEventCode = piaEventCode
            self.piaReleaseUrl = piaReleaseUrl
            self.piaEventUrl = piaEventUrl
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
    public typealias Request = CreateLive.Request
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

public struct GetPendingRequestCount: EndpointProtocol {
    public typealias Request = Empty
    public struct Response: Codable {
        public init(pendingRequestCount: Int) {
            self.pendingRequestCount = pendingRequestCount
        }

        public var pendingRequestCount: Int
    }
    public struct URI: CodableURL {
        @StaticPath("lives", "pending_request_count") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct LiveDetail: Codable {
    public init(
        live: Live, isLiked: Bool, likeCount: Int, postCount: Int, participatingFriends: [User]
    ) {
        self.live = live
        self.isLiked = isLiked
        self.likeCount = likeCount
        self.postCount = postCount
        self.participatingFriends = participatingFriends

        self.participants = 0
        self.ticket = nil
    }

    public var live: Live
    public var isLiked: Bool
    public var hasTicket: Bool {
        ticket != nil
    }
    public var participants: Int
    public var likeCount: Int
    public var ticket: Ticket?
    public var postCount: Int
    public var participatingFriends: [User]
}

public struct GetLive: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = LiveDetail
    public struct URI: CodableURL {
        @StaticPath("lives") public var prefix: Void
        @DynamicPath public var liveId: Live.ID
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct RefundTicket: EndpointProtocol {
    public struct Request: Codable {
        public let liveId: Live.ID
        public init(liveId: Live.ID) {
            self.liveId = liveId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("lives", "refund") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct ReserveTicket: EndpointProtocol {
    public struct Request: Codable {
        public let liveId: Live.ID
        public init(liveId: Live.ID) {
            self.liveId = liveId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("lives", "reserve") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetMyTickets: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<LiveFeed>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("lives", "my_tickets") public var prefix: Void
        @Query public var userId: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetLivePosts: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<PostSummary>

    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("lives") public var prefix: Void
        @DynamicPath public var liveId: Live.ID
        @StaticPath("posts") public var suffix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetMyLivePosts: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<PostSummary>

    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("lives") public var prefix: Void
        @DynamicPath public var liveId: Live.ID
        @StaticPath("posts", "mine") public var suffix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetLiveParticipants: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<User>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("lives", "participants") public var prefix: Void
        @DynamicPath public var liveId: Live.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct SearchLive: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<LiveFeed>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("lives", "search") public var prefix: Void
        @Query public var term: String?
        @Query public var groupId: Group.ID?
        @Query public var fromDate: String?
        @Query public var toDate: String?
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}
