import Domain
import FluentKit

public class UserRepository: Domain.UserRepository {
    private let db: Database
    public enum Error: Swift.Error {
        case alreadyCreated
        case userNotFound
        case deviceAlreadyRegistered
        case cantChangeRole
    }

    public init(db: Database) {
        self.db = db
    }

    public func create(cognitoId: CognitoID, email: String, input: Signup.Request)
        -> EventLoopFuture<Endpoint.User>
    {
        let existing = User.query(on: db).filter(\.$cognitoId == cognitoId).first()
        return existing.guard({ $0 == nil }, else: Error.alreadyCreated)
            .flatMap { [db] _ -> EventLoopFuture<Endpoint.User> in
                let storedUser = User(
                    cognitoId: cognitoId, email: email,
                    name: input.name, biography: input.biography,
                    thumbnailURL: input.thumbnailURL, role: input.role
                )
                return storedUser.create(on: db).flatMap { [db] in
                    Endpoint.User.translate(fromPersistance: storedUser, on: db)
                }
            }
    }

    public func editInfo(userId: Domain.User.ID, input: EditUserInfo.Request)
        -> EventLoopFuture<Endpoint.User>
    {
        let user = User.find(userId.rawValue, on: db).unwrap(orError: Error.userNotFound)
        return user.flatMapThrowing { user -> User in
            user.name = input.name
            user.biography = input.biography
            user.thumbnailURL = input.thumbnailURL
            switch (user.role, input.role) {
            case (.artist, .artist(let artist)):
                user.part = artist.part
            case (.fan, .fan): break
            default:
                throw Error.cantChangeRole
            }
            return user
        }
        .flatMap { [db] user in
            return user.update(on: db).transform(to: user)
        }
        .flatMap { [db] user in
            Endpoint.User.translate(fromPersistance: user, on: db)
        }
    }

    public func find(by cognitoId: Domain.CognitoID) -> EventLoopFuture<Endpoint.User?> {
        let maybeUser = User.query(on: db).filter(\.$cognitoId == cognitoId).first()
        return maybeUser.optionalFlatMap { [db] user in
            Endpoint.User.translate(fromPersistance: user, on: db)
        }
    }

    public func isExists(by id: Domain.User.ID) -> EventLoopFuture<Bool> {
        User.find(id.rawValue, on: db).map { $0 != nil }
    }

    public func endpointArns(for id: Domain.User.ID) -> EventLoopFuture<[String]> {
        UserDevice.query(on: db).filter(\.$user.$id == id.rawValue).all().map {
            $0.map(\.endpointArn)
        }
    }

    public func setEndpointArn(_ endpointArn: String, for id: Domain.User.ID) -> EventLoopFuture<
        Void
    > {
        let isExisting = UserDevice.query(on: db)
            .filter(\.$user.$id == id.rawValue)
            .filter(\.$endpointArn == endpointArn)
            .first().map { $0 != nil }
        let device = UserDevice(endpointArn: endpointArn, user: id.rawValue)
        let precondition = isExisting.and(isExists(by: id)).flatMapThrowing {
            guard $1 else { throw Error.userNotFound }
            guard !$0 else { throw Error.deviceAlreadyRegistered }
            return
        }
        return precondition.flatMap { [db] in
            device.save(on: db)
        }
    }
}
