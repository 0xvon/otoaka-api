import Fluent
import NIO

protocol EntityConvertible {
    associatedtype PersistanceEntity
    static func translate(fromPersistance entity: PersistanceEntity, on db: Database)
        -> EventLoopFuture<Self>
    func asPersistance() -> PersistanceEntity
}
