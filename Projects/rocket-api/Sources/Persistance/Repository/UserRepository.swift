import Domain
import Fluent

public class UserRepository: Domain.UserRepository {
    private let db: Database
    public enum Error: Swift.Error {
        case alreadyCreated
    }

    public init(db: Database) {
        self.db = db
    }

    public func create(foreignId: Domain.User.ForeignID) -> EventLoopFuture<Domain.User> {
        let existing = User.query(on: db).filter(\.$foreignId == foreignId).first()
        return existing.guard({ $0 == nil }, else: Error.alreadyCreated)
            .flatMap { [db] _ -> EventLoopFuture<Domain.User> in
                let storedUser = User(foreignId: foreignId)
                return storedUser.create(on: db)
                    .map { Domain.User(from: storedUser) }
            }
    }

    public func find(by foreignId: Domain.User.ForeignID) -> EventLoopFuture<Domain.User?> {
        let maybeUser = User.query(on: db).filter(\.$foreignId == foreignId).first()
        return maybeUser.map { maybeUser in
            guard let user = maybeUser else { return nil }
            let domainUser = Domain.User(from: user)
            return domainUser
        }
    }
}

extension Domain.User {
    fileprivate init(from storedUser: User) {
        self.init(id: storedUser.foreignId)
    }
}
