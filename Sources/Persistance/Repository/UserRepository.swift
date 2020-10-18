import Domain
import Fluent
import Endpoint

public class UserRepository: Domain.UserRepository {
    private let db: Database
    public enum Error: Swift.Error {
        case alreadyCreated
    }

    public init(db: Database) {
        self.db = db
    }

    public func create(
        cognitoId: Domain.User.CognitoID, email: String, name: String,
        biography: String?, thumbnailURL: String?,
        role: Domain.RoleProperties
    ) -> EventLoopFuture<Domain.User> {
        let existing = User.query(on: db).filter(\.$cognitoId == cognitoId).first()
        return existing.guard({ $0 == nil }, else: Error.alreadyCreated)
            .flatMap { [db] _ -> EventLoopFuture<Domain.User> in
                let storedUser = User(cognitoId: cognitoId, email: email, name: name, biography: biography, thumbnailURL: thumbnailURL, role: role)
                return storedUser.create(on: db)
                    .flatMapThrowing { try Domain.User(fromPersistance: storedUser) }
            }
    }

    public func find(by cognitoId: Domain.User.CognitoID) -> EventLoopFuture<Domain.User?> {
        let maybeUser = User.query(on: db).filter(\.$cognitoId == cognitoId).first()
        return maybeUser.flatMapThrowing { maybeUser in
            guard let user = maybeUser else { return nil }
            let domainUser = try Domain.User(fromPersistance: user)
            return domainUser
        }
    }
}
