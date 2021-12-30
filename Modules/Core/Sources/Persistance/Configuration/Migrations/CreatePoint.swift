import FluentKit

struct CreatePoint: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Point.schema)
            .id()
            .field("value", .int64, .required)
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .field("expired_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Point.schema).delete().map { _ in }
    }
    
    
}
