protocol EntityConvertible {
    associatedtype PersistanceEntity
    init(fromPersistance entity: PersistanceEntity) throws
    func asPersistance() -> PersistanceEntity
}
