import FluentKit

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("cognito_id", .string, .required)
            .unique(on: "cognito_id")

            .field("biography", .string)
            .field("thumbnail_url", .string)

            .field(
                "role",
                .enum(
                    DatabaseSchema.DataType.Enum(name: "role", cases: ["artist", "fan"])
                )
            )
            .field("part", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema).delete()
    }
}

struct CreateFollowing: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Following.schema)
            .id()
            .field("self_user_id", .uuid, .required)
            .foreignKey("self_user_id", references: User.schema, .id)
            .field("target_group_id", .uuid, .required)
            .foreignKey("target_group_id", references: Group.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Following.schema).delete()
    }
}

struct CreateUserDevice: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserDevice.schema)
            .id()
            .field("endpoint_arn", .string, .required)
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .unique(on: "endpoint_arn", "user_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserDevice.schema).delete()
    }
}

struct CreateLiveLike: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(LiveLike.schema)
            .id()
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .field("live_id", .uuid, .required)
            .foreignKey("live_id", references: Live.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(LiveLike.schema).delete()
    }
}

public protocol PersistanceUser: AnyObject {
    var cognitoId: String { get }
    var cognitoUsername: String? { get set }
}

extension User: PersistanceUser {}

struct CognitoSubToUsername: Migration {
    let migrator: (_ users: [PersistanceUser]) -> EventLoopFuture<Void>

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let addColumn = database.schema(User.schema)
            .field("cognito_username", .string)
            .unique(on: "cognito_username")
            .update()

        return addColumn.flatMap {
            User.query(on: database)
                .filter(\.$cognitoUsername == nil)
                .all()
                .flatMap { users in
                    migrator(users).map { users }
                }
                .flatMapEach(on: database.eventLoop) {
                    $0.save(on: database)
                }
                .transform(to: ())
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .deleteField("cognito_username")
            .update()
    }
}

struct CreateUserFollowing: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserFollowing.schema)
            .id()
            .field("self_user_id", .uuid, .required)
            .foreignKey("self_user_id", references: User.schema, .id)
            .field("target_user_id", .uuid, .required)
            .foreignKey("target_user_id", references: User.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserFollowing.schema).delete()
    }
}

struct CreateUserFeed: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let typeEnum = database.enum("user_feed_type")
            .case("youtube")
            .create()
        return typeEnum.flatMap { typeEnum in
            database.schema(UserFeed.schema)
                .id()
                .field("text", .string, .required)
                .field("feed_type", typeEnum, .required)
                .field("youtube_url", .string)
                .field("author_id", .uuid)
                .foreignKey("author_id", references: User.schema, "id")
                .field("ogp_url", .string)
                .field("group_id", .uuid, .required)
                .foreignKey("group_id", references: Group.schema, "id")
                .field("title", .string, .required)
                .field("created_at", .datetime, .required)
                .field("deleted_at", .datetime)
                .create()
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserFeed.schema).delete()
    }
}

struct CreateUserFeedComment: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserFeedComment.schema)
            .id()
            .field("text", .string)
            .field("user_feed_id", .uuid, .required)
            .foreignKey("user_feed_id", references: UserFeed.schema, "id")
            .field("author_id", .uuid, .required)
            .foreignKey("author_id", references: User.schema, "id")
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ArtistFeedComment.schema).delete()
    }
}

struct CreateUserFeedLike: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserFeedLike.schema)
            .id()
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .field("user_feed_id", .uuid, .required)
            .foreignKey("user_feed_id", references: UserFeed.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserFeedLike.schema).delete()
    }
}

struct ThumbnailUrlAndAppleMusicToUserFeed: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let typeEnum = database.enum("user_feed_type")
            .case("apple_music")
            .update()
        
        return typeEnum.flatMap { typeEnum in
            database.schema(UserFeed.schema)
                .field("thumbnail_url", .string)
                .field("apple_music_song_id", .string)
                .updateField("feed_type", typeEnum)
                .update()
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserFeed.schema)
            .deleteField("thumbnail_url")
            .deleteField("apple_music_song_id")
            .update()
    }
}

struct InstagramAndTwitterUrlToUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .field("instagram_url", .string)
            .field("twitter_url", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .deleteField("instagram_url")
            .deleteField("twitter_url")
            .update()
    }
}

struct CreateUserNotification: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserNotification.schema)
            .id()
            .field("is_read", .bool, .required)
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .field(
                "notification_type",
                .enum(
                    DatabaseSchema.DataType.Enum(name: "notification_type", cases: ["follow", "like", "comment", "official_announce"])
                )
            )
            .field("followed_by_id", .uuid)
            .foreignKey("followed_by_id", references: User.schema, .id)
            .field("liked_user_id", .uuid)
            .foreignKey("liked_user_id", references: User.schema, .id)
            .field("liked_feed_id", .uuid)
            .foreignKey("liked_feed_id", references: UserFeed.schema, .id)
            .field("feed_comment_id", .uuid)
            .foreignKey("feed_comment_id", references: UserFeedComment.schema, .id)
            .field("title", .string)
            .field("url", .string)
            .field("created_at", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserNotification.schema)
            .delete()
    }
}
