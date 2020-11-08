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
    associatedtype QueryParameters: Codable = Empty

    static var method: HTTPMethod { get }
    static var pathPattern: [String] { get }
    static func buildPath(with parameters: Parameters, query: QueryParameters) -> [String]
}

public struct Empty: Codable {
    public init() {}
}

public struct PaginatedResponse<Item: Codable>: Codable {
    public var lastEvaluatedId: String
    public var items: [Item]
}

public struct PaginatedRequest<Item: Codable> {
    public var exclusiveStartId: String
}
