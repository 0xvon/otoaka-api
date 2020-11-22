import Fluent

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
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserDevice.schema).delete()
    }
}
