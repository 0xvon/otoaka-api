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
