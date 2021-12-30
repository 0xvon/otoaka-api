import Domain
import FluentKit
import Foundation

final class Point: Model {
    static var schema: String = "points"
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "value")
    var value: Int
    
    @Parent(key: "user_id")
    var user: User
    
    @OptionalField(key: "expired_at")
    var expiredAt: Date?
    
    init() {}
    
    init(
        id: UUID? = nil,
        value: Int,
        userId: Domain.User.ID,
        expiredAt: Date?
    ) {
        self.id = id
        self.value = value
        self.$user.id = userId.rawValue
        self.expiredAt = expiredAt
    }
}

extension Endpoint.Point {
    static func translate(fromPersistance entity: Point, on db: Database) async throws -> Self {
        let user = try await Domain.User.translate(
            fromPersistance: entity.$user.get(on: db)
            , on: db
        ).get()
        let id = try entity.requireID()
        return Self.init(id: ID(id), user: user, value: entity.value, expiredAt: entity.expiredAt)
    }
}
