public enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

public protocol EndpointProtocol {
    associatedtype Request: Codable
    associatedtype Response: Codable
    associatedtype Parameters

    static var method: HTTPMethod { get }
    static var pathPattern: [String] { get }
    static func buildPath(with parameters: Parameters) -> [String]
}

public struct Empty: Codable {}

public struct Signup: EndpointProtocol {
    public struct Request: Codable {
        public var displayName: String
    }
    public struct Response: Codable {
        public var displayName: String
    }
    public static let method: HTTPMethod = .post
    public static let pathPattern = ["users", "signup"]
    public static func buildPath(with parameters: Void) -> [String] {
        return pathPattern
    }
}

public struct GetUserInfo: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Empty
    public static let method: HTTPMethod = .get
    public static let pathPattern = ["users", "get_info"]
    public static func buildPath(with parameters: Void) -> [String] {
        return pathPattern
    }
}

public struct GetBand: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Empty
    public static let method: HTTPMethod = .get
    public typealias Parameters = Int

    public static let pathPattern = ["bands", ":band_id"]
    public static func buildPath(with bandId: Parameters) -> [String] {
        ["bands", bandId.description]
    }
}
