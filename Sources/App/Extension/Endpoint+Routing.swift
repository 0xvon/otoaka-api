import Endpoint
import Vapor

extension Endpoint.HTTPMethod {
    var vaporize: NIOHTTP1.HTTPMethod {
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
        use closure: @escaping (Request) throws -> Response
    ) {
        on(Endpoint.method.vaporize, Endpoint.pathPattern.map(PathComponent.init(stringLiteral:)), use: closure)
    }
}
