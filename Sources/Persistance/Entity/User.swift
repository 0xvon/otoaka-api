import Domain
import Fluent
import Foundation

final class User: Model {
    static var schema: String = "users"
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "foreign_id")
    var foreignId: ForeignIdentifier<Domain.User>

    init(foreignId: ForeignIdentifier<Domain.User>) {
        self.foreignId = foreignId
    }
    init() {
        foreignId = ForeignIdentifier(stringLiteral: "")
    }
}
