import Domain
import FluentKit

public class PointRepository: Domain.PointRepository {
    public let db: Database
    public enum Error: Swift.Error {
        case noEnoughPoints
    }
    
    public init(db: Database) {
        self.db = db
    }
    
    public func add(userId: Domain.User.ID, input: AddPoint.Request) async throws -> Domain.Point {
        if let point = try await Point.query(on: db).filter(\.$user.$id == userId.rawValue).first() {
            point.value += input.point
            try await point.update(on: db)
            return try await Domain.Point.translate(fromPersistance: point, on: db)
        } else {
            let point = Point(value: input.point, userId: userId, expiredAt: input.expiredAt)
            try await point.create(on: db)
            return try await Domain.Point.translate(fromPersistance: point, on: db)
        }
        
        
    }
    
    public func use(userId: Domain.User.ID, input: UsePoint.Request) async throws -> Domain.Point {
        guard let point = try await Point.query(on: db).filter(\.$user.$id == userId.rawValue).first() else {
            throw Error.noEnoughPoints
            
        }
        guard point.value >= input.point else {
            throw Error.noEnoughPoints
        }
        
        point.value -= input.point
        try await point.update(on: db)
        return try await Domain.Point.translate(fromPersistance: point, on: db)
    }
}
