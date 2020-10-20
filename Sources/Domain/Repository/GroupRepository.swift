import Foundation
import NIO

public protocol GroupRepository {
    func create(
        name: String, englishName: String?,
        biography: String?, since: Date?, artworkURL: URL?,
        hometown: String?
    ) -> EventLoopFuture<Domain.Group>
}
