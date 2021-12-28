import FluentKit

struct CreateGroup: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Group.schema)
            .id()
            .field("name", .string, .required)
            .field("english_name", .string)
            .field("biography", .string)
            .field("since", .date)
            .field("artwork_url", .string)
            .field("twitter_id", .string)
            .field("youtube_channel_id", .string)
            .field("hometown", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Group.schema).delete()
    }
}

struct CreateMembership: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Membership.schema)
            .id()
            .field("group_id", .uuid, .required)
            .foreignKey("group_id", references: Group.schema, "id")
            .field("artist_id", .uuid, .required)
            .foreignKey("artist_id", references: User.schema, "id")
            .field("is_leader", .bool, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Membership.schema).delete()
    }
}

struct CreateGroupInvitation: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(GroupInvitation.schema)
            .id()
            .field("group_id", .uuid, .required)
            .foreignKey("group_id", references: Group.schema, "id")
            .field("invited", .bool, .required)
            .field("membership_id", .uuid)
            .foreignKey("membership_id", references: Membership.schema, "id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(GroupInvitation.schema).delete()
    }
}

struct CreateGroupFeed: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let typeEnum = database.enum("group_feed_type")
            .case("youtube")
            .create()
        return typeEnum.flatMap { typeEnum in
            database.schema(ArtistFeed.schema)
                .id()
                .field("text", .string, .required)
                .field("feed_type", typeEnum, .required)
                .field("youtube_url", .string)
                .field("author_id", .uuid)
                .foreignKey("author_id", references: User.schema, "id")
                .field("created_at", .datetime, .required)
                .create()
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ArtistFeed.schema).delete()
    }
}

struct CreateArtistFeedComment: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ArtistFeedComment.schema)
            .id()
            .field("text", .string)
            .field("artist_feed_id", .uuid, .required)
            .foreignKey("artist_feed_id", references: ArtistFeed.schema, "id")
            .field("author_id", .uuid, .required)
            .foreignKey("author_id", references: User.schema, "id")
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ArtistFeedComment.schema).delete()
    }
}

struct AddDeletedAtFieldToGroup: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Group.schema)
            .field("deleted_at", .datetime)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Group.schema)
            .deleteField("deleted_at")
            .update()
    }
}

struct AddDeletedAtFieldToArtistFeed: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ArtistFeed.schema)
            .field("deleted_at", .datetime)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ArtistFeed.schema)
            .deleteField("deleted_at")
            .update()
    }
}

struct ThumbnailUrlAndAppleMusicToArtistFeed: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let typeEnum = database.enum("group_feed_type")
            .case("apple_music")
            .update()
        return typeEnum.flatMap { typeEnum in
            database.schema(ArtistFeed.schema)
                .field("thumbnail_url", .string)
                .field("apple_music_song_id", .string)
                .updateField("feed_type", typeEnum)
                .update()
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ArtistFeed.schema)
            .deleteField("thumbnail_url")
            .deleteField("apple_music_song_id")
            .update()
    }
}

struct CreateGroupEntry: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(GroupEntry.schema)
            .id()
            .field("group_id", .uuid, .required)
            .foreignKey("group_id", references: Group.schema, .id)
            .field("entried_at", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(GroupEntry.schema).delete()
    }
}
