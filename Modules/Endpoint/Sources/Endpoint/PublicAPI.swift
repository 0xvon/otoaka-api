import Foundation

public struct GetUserProfile: EndpointProtocol {
    public typealias Request = Empty
    public struct Response: Codable {
        public var user: User
        public var transition: LiveTransition
        public var frequentlyWatchingGroups: [GroupFeed]
        public var recentlyFollowingGroups: [GroupFeed]
        public var followingGroups: [GroupFeed]
        public var liveSchedule: [LiveFeed]

        public init(
            user: User,
            transition: LiveTransition,
            frequentlyWatchingGroups: [GroupFeed],
            recentlyFollowingGroups: [GroupFeed],
            followingGroups: [GroupFeed],
            liveSchedule: [LiveFeed]
        ) {
            self.user = user
            self.transition = transition
            self.frequentlyWatchingGroups = frequentlyWatchingGroups
            self.recentlyFollowingGroups = recentlyFollowingGroups
            self.followingGroups = followingGroups
            self.liveSchedule = liveSchedule
        }
    }
    public struct URI: CodableURL {
        @StaticPath("public", "user_profile") public var prefix: Void
        @DynamicPath public var username: String
        public init() {}
    }

    public static let method: HTTPMethod = .get
}

public struct GetLiveInfo: EndpointProtocol {
    public typealias Request = Empty
    public struct Response: Codable {
        public var live: Live
        public var likeCount: Int

        public init(
            live: Live,
            likeCount: Int
        ) {
            self.live = live
            self.likeCount = likeCount
        }
    }
    public struct URI: CodableURL {
        @StaticPath("public", "live_info") public var prefix: Void
        @DynamicPath public var liveId: Live.ID
        public init() {}
    }

    public static let method: HTTPMethod = .get
}
