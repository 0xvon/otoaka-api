import Endpoint

protocol EndpointResponseConvertible {
    associatedtype EndpointResponse: Codable
    func asEndpointResponse() -> EndpointResponse
}
