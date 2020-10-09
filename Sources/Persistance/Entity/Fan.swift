import Domain
import Fluent
import Foundation

final class Fan: Model {
    static let schema = "fans"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "display_name")
    var displayName: String

    init() {}

    init(id: UUID? = nil, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

extension Fan {
    var toDomain: Domain.Fan {
        Domain.Fan(
            id: id,
            displayName: displayName
        )
    }
}

extension Domain.Fan {
    var toData: Fan {
        Fan(
            id: id,
            displayName: displayName
        )
    }
}
