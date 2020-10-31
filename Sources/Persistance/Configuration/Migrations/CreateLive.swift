import Fluent

struct CreateLive: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let styleEnum = database.enum("live_style")
            .case("oneman")
            .case("battle")
            .case("festival")
            .create()

        return styleEnum.flatMap { styleEnum in
            return database.schema(Live.schema)
                .id()
                .field("title", .string, .required)
                .field("style", styleEnum, .required)
                .field("artwork_url", .string)
                .field("host_group_id", .uuid)
                .foreignKey("host_group_id", references: Group.schema, .id)
                .field("author_id", .uuid)
                .foreignKey("author_id", references: User.schema, .id)
                .field("open_at", .datetime)
                .field("start_at", .datetime)
                .field("end_at", .datetime)
                .create()
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Live.schema).delete()
            .and(database.enum("live_style").delete())
            .map { _ in }
    }
}

struct CreateLivePerformer: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(LivePerformer.schema)
            .id()
            .field("live_id", .uuid, .required)
            .field("group_id", .uuid, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(LivePerformer.schema).delete()
    }
}