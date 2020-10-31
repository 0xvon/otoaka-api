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

public struct Empty: Codable {
    public init() {}
}
