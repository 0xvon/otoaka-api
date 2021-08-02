import Foundation

public struct FollowGroup: EndpointProtocol {
    public struct Request: Codable {
        public var id: Group.ID
        public init(groupId: Group.ID) {
            self.id = groupId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "follow_group") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UnfollowGroup: EndpointProtocol {
    public struct Request: Codable {
        public var id: Group.ID
        public init(groupId: Group.ID) {
            self.id = groupId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "unfollow_group") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GroupFollowers: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<User>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "group_followers") public var prefix: Void
        @DynamicPath public var id: Group.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct FollowingGroups: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<Group>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "following_groups") public var prefix: Void
        @DynamicPath public var id: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct FollowUser: EndpointProtocol {
    public struct Request: Codable {
        public var id: User.ID
        public init(userId: User.ID) {
            self.id = userId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "follow_user") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UnfollowUser: EndpointProtocol {
    public struct Request: Codable {
        public var id: User.ID
        public init(userId: User.ID) {
            self.id = userId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "unfollow_user") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UserFollowers: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<User>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "user_followers") public var prefix: Void
        @DynamicPath public var id: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct FollowingUsers: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<User>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "following_users") public var prefix: Void
        @DynamicPath public var id: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct BlockUser: EndpointProtocol {
    public struct Request: Codable {
        public var id: User.ID
        public init(userId: User.ID) {
            self.id = userId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "block_user") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UnblockUser: EndpointProtocol {
    public struct Request: Codable {
        public var id: User.ID
        public init(userId: User.ID) {
            self.id = userId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "unblock_user") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct RecommendedUsers: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<User>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "recommended_users") public var prefix: Void
        @DynamicPath public var id: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct LiveFeed: Codable {
    public var live: Live
    public var isLiked: Bool
    public var hasTicket: Bool
    public var likeCount: Int
    public var participantCount: Int

    public init(live: Live, isLiked: Bool, hasTicket: Bool, likeCount: Int, participantCount: Int) {
        self.live = live
        self.isLiked = isLiked
        self.hasTicket = hasTicket
        self.likeCount = likeCount
        self.participantCount = participantCount
    }
}

public struct GetUpcomingLives: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<LiveFeed>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "upcoming_lives") public var prefix: Void
        @Query public var userId: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

@dynamicMemberLookup
public struct ArtistFeedSummary: Codable, Equatable {
    public var feed: ArtistFeed
    public var commentCount: Int

    public subscript<T>(dynamicMember keyPath: KeyPath<ArtistFeed, T>) -> T {
        feed[keyPath: keyPath]
    }

    public init(feed: ArtistFeed, commentCount: Int) {
        self.feed = feed
        self.commentCount = commentCount
    }
}

public struct GetFollowingGroupFeeds: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<ArtistFeedSummary>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "group_feeds") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct LikeUserFeed: EndpointProtocol {
    public struct Request: Codable {
        public var feedId: UserFeed.ID
        public init(feedId: UserFeed.ID) {
            self.feedId = feedId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "like_user_feed") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UnlikeUserFeed: EndpointProtocol {
    public struct Request: Codable {
        public var feedId: UserFeed.ID
        public init(feedId: UserFeed.ID) {
            self.feedId = feedId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "unlike_user_feed") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

@dynamicMemberLookup
public struct UserFeedSummary: Codable, Equatable {
    public var feed: UserFeed
    public var commentCount: Int
    public var likeCount: Int
    public var isLiked: Bool

    public subscript<T>(dynamicMember keyPath: KeyPath<UserFeed, T>) -> T {
        feed[keyPath: keyPath]
    }

    public init(feed: UserFeed, commentCount: Int, likeCount: Int, isLiked: Bool) {
        self.feed = feed
        self.commentCount = commentCount
        self.likeCount = likeCount
        self.isLiked = isLiked
    }
}

@dynamicMemberLookup
public struct PostSummary: Codable, Equatable {
    public var post: Post
    public var commentCount: Int
    public var likeCount: Int
    public var isLiked: Bool
    
    public subscript<T>(dynamicMember keyPath: KeyPath<Post, T>) -> T {
        post[keyPath: keyPath]
    }
    
    public init(
        post: Post, commentCount: Int, likeCount: Int, isLiked: Bool
    ) {
        self.post = post
        self.commentCount = commentCount
        self.likeCount = likeCount
        self.isLiked = isLiked
    }
}

public struct GetFollowingUserFeeds: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<UserFeedSummary>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "following_user_feeds") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetLikedUserFeeds: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<UserFeedSummary>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "liked_user_feeds") public var prefix: Void
        @DynamicPath public var userId: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetAllUserFeeds: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<UserFeedSummary>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "all_user_feeds") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct LikeLive: EndpointProtocol {
    public struct Request: Codable {
        public var liveId: Live.ID
        public init(liveId: Live.ID) {
            self.liveId = liveId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "like_live") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UnlikeLive: EndpointProtocol {
    public struct Request: Codable {
        public var liveId: Live.ID
        public init(liveId: Live.ID) {
            self.liveId = liveId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "unlike_live") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetLikedLive: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<LiveFeed>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "liked_live") public var prefix: Void
        @DynamicPath public var userId: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct PostFeedComment: EndpointProtocol {
    public struct Request: Codable {
        public var feedId: ArtistFeed.ID
        public var text: String
        public init(feedId: ArtistFeed.ID, text: String) {
            self.feedId = feedId
            self.text = text
        }
    }
    public typealias Response = ArtistFeedComment
    public struct URI: CodableURL {
        @StaticPath("user_social", "feed_comment") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetFeedComments: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<ArtistFeedComment>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "feed_comment") public var prefix: Void
        @DynamicPath public var feedId: ArtistFeed.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct PostUserFeedComment: EndpointProtocol {
    public struct Request: Codable {
        public var feedId: UserFeed.ID
        public var text: String
        public init(feedId: UserFeed.ID, text: String) {
            self.feedId = feedId
            self.text = text
        }
    }
    public typealias Response = UserFeedComment
    public struct URI: CodableURL {
        @StaticPath("user_social", "user_feed_comment") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetUserFeedComments: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<UserFeedComment>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "user_feed_comment") public var prefix: Void
        @DynamicPath public var feedId: UserFeed.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetFollowingPosts: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<PostSummary>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "following_posts") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct GetLikedPosts: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<PostSummary>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "liked_posts") public var prefix: Void
        @DynamicPath public var userId: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct GetAllPosts: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<PostSummary>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "all_posts") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct AddPostComment: EndpointProtocol {
    public struct Request: Codable {
        public var postId: Post.ID
        public var text: String
        public init(postId: Post.ID, text: String) {
            self.postId = postId
            self.text = text
        }
    }
    public typealias Response = PostComment
    public struct URI: CodableURL {
        @StaticPath("user_social", "add_post_comment") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}

public struct GetPostComments: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<PostComment>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "post_comments") public var prefix: Void
        @DynamicPath public var postId: Post.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct LikePost: EndpointProtocol {
    public struct Request: Codable {
        public var postId: Post.ID
        public init(postId: Post.ID) {
            self.postId = postId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "like_post") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UnlikePost: EndpointProtocol {
    public struct Request: Codable {
        public var postId: Post.ID
        public init(postId: Post.ID) {
            self.postId = postId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "unlike_post") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}
