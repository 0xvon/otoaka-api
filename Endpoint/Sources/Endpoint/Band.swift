import Foundation

public struct Group: Codable {
    public let id: String
    public var name: String
    public var englishName: String?
    public var biography: String?
    public var since: Date?
    public var artworkURL: URL?
    public var hometown: String?
    public init(id: String, name: String, englishName: String?,
                biography: String?, since: Date?,
                artworkURL: URL?, hometown: String?)
    {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.biography = biography
        self.since = since
        self.artworkURL = artworkURL
        self.hometown = hometown
    }
}

public struct CreateGroup: EndpointProtocol {
    public struct Request: Codable {
        public var name: String
        public var englishName: String?
        public var biography: String?
        public var since: Date?
        public var artworkURL: URL?
        public var hometown: String?

        public init(name: String, englishName: String?, biography: String?,
                    since: Date?, artworkURL: URL?, hometown: String?)
        {
            self.name = name
            self.englishName = englishName
            self.biography = biography
            self.since = since
            self.artworkURL = artworkURL
            self.hometown = hometown
        }
    }

    public typealias Response = Group
    public static let method: HTTPMethod = .post
    public typealias Parameters = Void

    public static let pathPattern = ["bands"]
    public static func buildPath(with _: Parameters) -> [String] {
        pathPattern
    }
}

public struct InviteGroup: EndpointProtocol {
    public struct Request: Codable {
        public var groupId: String
        public init(groupId: String) {
            self.groupId = groupId
        }
    }

    public struct Invitation: Codable {
        public var id: String

        public init(id: String) {
            self.id = id
        }
    }

    public typealias Response = Invitation
    public static let method: HTTPMethod = .post
    public typealias Parameters = Void

    public static let pathPattern = ["bands", "invite"]
    public static func buildPath(with _: Parameters) -> [String] {
        pathPattern
    }
}
