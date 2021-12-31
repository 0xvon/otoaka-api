import CodableURL
import Foundation

public struct AddPoint: EndpointProtocol {
    public struct Request: Codable {
        public var point: Int
        public var expiredAt: Date?
        public init(point: Int, expiredAt: Date?) {
            self.point = point
            self.expiredAt = expiredAt
        }
    }
    public typealias Response = Point
    public struct URI: CodableURL {
        @StaticPath("points", "add") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}

public struct UsePoint: EndpointProtocol {
    public struct Request: Codable {
        public var point: Int
        public init(point: Int) {
            self.point = point
        }
    }
    public typealias Response = Point
    public struct URI: CodableURL {
        @StaticPath("points", "use") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}

public struct GetMyPoint: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Int
    public struct URI: CodableURL {
        @StaticPath("points", "mine") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}
