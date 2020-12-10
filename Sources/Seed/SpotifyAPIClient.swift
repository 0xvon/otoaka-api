import AsyncHTTPClient
import Endpoint
import Foundation
import NIO
import NIOHTTP1

enum SpotifyAPI {}
extension SpotifyAPI {
    struct Page<Item: Codable>: Codable {
        let items: [Item]
    }
    struct GetPlaylistItems: EndpointProtocol {
        typealias Request = Empty
        typealias Response = Page<Item>
        struct Item: Codable {
            let track: Track
        }
        struct Track: Codable {
            let album: Album
        }
        struct Album: Codable {
            let artists: [Artist]
        }
        struct Artist: Codable, Hashable {
            let id: String
            let name: String
        }

        // playlists/37i9dQZF1DX54Fkcz35jfT/tracks
        struct URI: CodableURL {
            @StaticPath("playlists") var prefix: Void
            @DynamicPath var playlistId: String
            @StaticPath("tracks") var suffix: Void
        }
        static var method: Endpoint.HTTPMethod = .get
    }
    // https://api.spotify.com/v1/artists/3ZUMuYvHWk19cbT0EGyJ8o
    struct GetArtist: EndpointProtocol {
        typealias Request = Empty
        struct Response: Codable {
            let name: String
            let images: [Image]

            var bestQualityImage: Image {
                images.max(by: { $0.height < $1.height })!
            }
        }
        struct Image: Codable {
            let height: Int
            let width: Int
            let url: String
        }

        struct URI: CodableURL {
            @StaticPath("artists") var prefix: Void
            @DynamicPath var artistId: String
        }
        static var method: Endpoint.HTTPMethod = .get
    }
}

class SpotifyAPIClient {
    let spotifyAPIToken = Environment.get("SPOTIFY_API_TOKEN")!
    func makeHeaders() -> HTTPHeaders {
        HTTPHeaders([
            ("Accept", "application/json"),
            ("Content-Type", "application/json"),
            ("Authorization", "Bearer \(spotifyAPIToken)"),
        ])
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let http: AsyncHTTPClient.HTTPClient
    init(http: AsyncHTTPClient.HTTPClient) {
        self.http = http
    }

    func execute<E>(_: E.Type, uri: E.URI = E.URI(), request: E.Request? = nil) -> EventLoopFuture<
        E.Response
    > where E: EndpointProtocol {
        let url: URL
        do {
            url = try uri.encode(baseURL: URL(string: "https://api.spotify.com/v1")!)
            let body = try request.map { try encoder.encode($0) }
            let request = try HTTPClient.Request(
                url: url, method: .translate(from: E.method),
                headers: makeHeaders(),
                body: body.map(AsyncHTTPClient.HTTPClient.Body.data)
            )
            return http.execute(request: request)
                .flatMapThrowing { [decoder] in
                    var body = $0.body ?? ByteBuffer()
                    return try! body.readJSONDecodable(
                        E.Response.self, decoder: decoder, length: body.readableBytes)!
                }
        } catch {
            fatalError()
        }
    }
}
