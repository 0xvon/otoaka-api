import Domain
import Fluent
import Foundation

public class GroupRepository: Domain.GroupRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }

    public func create(
        name: String, englishName: String?, biography: String?,
        since: Date?, artworkURL: URL?, hometown: String?
    ) -> EventLoopFuture<Domain.Group> {
        let group = Group(name: name, englishName: englishName,
                          biography: biography, since: since,
                          artworkURL: artworkURL, hometown: hometown)
        return group.save(on: db).flatMapThrowing {
            try Domain.Group(fromPersistance: group)
        }
    }
}
