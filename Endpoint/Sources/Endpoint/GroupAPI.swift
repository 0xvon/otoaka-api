import Foundation

public struct CreateGroup: EndpointProtocol {
    public struct Request: Codable {
        public var name: String
        public var englishName: String?
        public var biography: String?
        public var since: Date?
        public var artworkURL: Foundation.URL?
        public var hometown: String?

        public init(
            name: String, englishName: String?, biography: String?,
            since: Date?, artworkURL: Foundation.URL?, hometown: String?
        ) {
            self.name = name
            self.englishName = englishName
            self.biography = biography
            self.since = since
            self.artworkURL = artworkURL
            self.hometown = hometown
        }
    }

    public typealias Response = Group
    public struct URI: CodableURL {
        @StaticPath("groups") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct EditGroup: EndpointProtocol {
    public typealias Request = CreateGroup.Request
    public typealias Response = Group
    public struct URI: CodableURL {
        @StaticPath("groups", "edit") public var prefix: Void
        @DynamicPath public var id: Group.ID
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct InviteGroup: EndpointProtocol {
    public struct Request: Codable {
        public var groupId: Group.ID
        public init(groupId: Group.ID) {
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
    public struct URI: CodableURL {
        @StaticPath("groups", "invite") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct JoinGroup: EndpointProtocol {
    public struct Request: Codable {
        public var invitationId: String

        public init(invitationId: String) {
            self.invitationId = invitationId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("groups", "join") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetGroup: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Group
    public struct URI: CodableURL {
        @StaticPath("groups") public var prefix: Void
        @DynamicPath public var groupId: Group.ID
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetMemberships: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = [Group]
    public struct URI: CodableURL {
        @StaticPath("groups", "memberships") public var prefix: Void
        @DynamicPath public var artistId: User.ID
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetAllGroups: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<Group>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("groups") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}
