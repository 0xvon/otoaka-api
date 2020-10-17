public enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

public protocol Endpoint {
    associatedtype Request: Codable
    associatedtype Response: Codable
    associatedtype Parameters

    static var method: HTTPMethod { get }
    static var path: Route<Parameters> { get }
}

public struct Empty: Codable {}

public struct Signup: Endpoint {
    public struct Request: Codable {
        public var displayName: String
    }
    public struct Response: Codable {
        public var displayName: String
    }
    public static let method: HTTPMethod = .post
    public static let path = const("signup")
}

public struct GetBand: Endpoint {
    public typealias Request = Empty
    public typealias Response = Empty
    public static let method: HTTPMethod = .get
    public static let path = const("bands")/int()
}
