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
        public var artworkURL: URL?
        public var hostGroupId: String
        // TODO: liveHouseId
        public var openAt: Date?
        public var startAt: Date?
        public var endAt: Date?
        public var performerGroupIds: [String]
        
        public init(title: String, style: LiveStyle, artworkURL: URL?, hostGroupId: String,
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
    public static let method: HTTPMethod = .post
    public static let pathPattern = ["lives"]
    public static func buildPath(with _: Void) -> [String] {
        pathPattern
    }
}
