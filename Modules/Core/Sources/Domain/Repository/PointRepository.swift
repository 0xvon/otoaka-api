import Endpoint
import Foundation
import NIO

public protocol PointRepository {
    func add(userId: Domain.User.ID, input: AddPoint.Request) async throws -> Point
    func use(userId: Domain.User.ID, input: UsePoint.Request) async throws -> Point
}
