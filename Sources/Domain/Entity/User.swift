import Foundation

public enum RoleProperties {
    case artist(Artist)
    case fan
}

public struct User {

    public typealias CognitoID = String
    public let id: UUID
    public let cognitoId: CognitoID
    public var email: String
    
    public var name: String
    public var biography: String?
    public var thumbnailURL: String?

    public var role: RoleProperties

    public init(
        id: UUID, cognitoId: User.CognitoID, email: String, name: String,
        biography: String?, thumbnailURL: String?, role: RoleProperties
    ) {
        self.id = id
        self.cognitoId = cognitoId
        self.email = email
        self.name = name
        self.biography = biography
        self.thumbnailURL = thumbnailURL
        self.role = role
    }
    
}
