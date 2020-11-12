import Endpoint
import Vapor

extension Endpoint.HTTPMethod {
    fileprivate var vaporize: NIOHTTP1.HTTPMethod {
        switch self {
        case .get: return .GET
        case .put: return .PUT
        case .post: return .POST
        case .delete: return .DELETE
        }
    }
}

extension RoutesBuilder {
    func on<Endpoint: EndpointProtocol, Response: ResponseEncodable>(
        endpoint _: Endpoint.Type,
        use closure: @escaping (Request, Endpoint.URI) throws -> Response
    ) throws {
        let (pathComponents, _) = try Endpoint.URI.placeholder(createPlaceholder: { ":\($0)" })
        on(
            Endpoint.method.vaporize, pathComponents.map(PathComponent.init(stringLiteral:)),
            use: { req in
                try closure(req, Endpoint.URI.decode(from: req))
            })
    }
}

extension CodableURL {
    static func decode(from request: Request) throws -> Self {
        try Self.decode(
            pathComponents: request.url.path.split(separator: "/").map(String.init),
            queryParameter: { try! request.query.get(at: $0) }
        )
    }
}
