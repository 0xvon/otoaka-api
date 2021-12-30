import Foundation

public struct Point: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public let id: ID
    public let user: User
    public let value: Int
    public let expiredAt: Date?
    
    public init(
        id: Self.ID,
        user: User,
        value: Int,
        expiredAt: Date?
    ) {
        self.id = id
        self.user = user
        self.value = value
        self.expiredAt = expiredAt
    }
}
