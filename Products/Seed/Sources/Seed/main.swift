import AsyncHTTPClient
import Endpoint
import Foundation
import NIO

let baseURL = Environment.get("API_ENDPOINT") ?? "http://localhost:8080"
let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
let cognito = CognitoClient()
let spotify = SpotifyAPIClient(http: httpClient)
let client = AppClient(
    baseURL: URL(string: baseURL)!, http: httpClient, cognito: cognito
)
let scrapedCachePath = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .appendingPathComponent(".cache.json")

func exportScrapedCache(_ users: [SpotifyAPI.GetArtist.Response]) {
    let data = try! JSONEncoder().encode(users)
    try! data.write(to: scrapedCachePath)
}

func importScrapedCache() -> [SpotifyAPI.GetArtist.Response]? {
    do {
        let data = try Data(contentsOf: scrapedCachePath)
        return try! JSONDecoder().decode([SpotifyAPI.GetArtist.Response].self, from: data)
    } catch {
        return nil
    }
}

func importSpotifyDataSoruces(eventLoop: EventLoop) throws {
    if let cache = importScrapedCache() {
        let future = EventLoopFuture.whenAllSucceed(
            cache.map { importSpotifyArtist(artist: $0, eventLoop: eventLoop) },
            on: eventLoop
        )
        _ = try future.wait()
        return
    }
    let playlists = ["37i9dQZF1DX54Fkcz35jfT"]
    _ = try EventLoopFuture.whenAllSucceed(
        playlists.map { playlist in
            spotify.execute(
                SpotifyAPI.GetPlaylistItems.self,
                uri: {
                    var uri = SpotifyAPI.GetPlaylistItems.URI()
                    uri.playlistId = playlist
                    return uri
                }()
            )
            .map { $0.items.flatMap(\.track.album.artists) }
        }, on: eventLoop
    )
    .map { Set($0.flatMap { $0 }) }
    .flatMap {
        EventLoopFuture.whenAllSucceed(
            $0.map { user -> EventLoopFuture<SpotifyAPI.GetArtist.Response> in
                var uri = SpotifyAPI.GetArtist.URI()
                uri.artistId = user.id
                return spotify.execute(SpotifyAPI.GetArtist.self, uri: uri)
            }, on: eventLoop)
    }
    .always {
        guard case .success(let users) = $0 else { return }
        exportScrapedCache(Array(users))
    }
    .flatMap {
        EventLoopFuture.whenAllSucceed(
            $0.map { importSpotifyArtist(artist: $0, eventLoop: eventLoop) }, on: eventLoop)
    }
    .wait()
}

func importSpotifyArtist(artist: SpotifyAPI.GetArtist.Response, eventLoop: EventLoop)
    -> EventLoopFuture<Void>
{

    let thumbnail = artist.bestQualityImage
    let futures = (0..<Int.random(in: 1..<5)).map { i -> EventLoopFuture<AppUser> in
        let userName = "\(artist.name) メンバー\(i)"
        let cognitoUserName = UUID().uuidString
        let user = cognito.createToken(userName: cognitoUserName)
        let request = Signup.Request(
            name: userName,
            biography: "\(userName)です。\(artist.name)で活動しています。(Imported from Spotify API)",
            thumbnailURL: thumbnail.url, role: .artist(Artist(part: "メンバー\(i)"))
        )
        return user.flatMap { cognitoUser in
            client.execute(Signup.self, request: request, as: cognitoUser.token)
                .map {
                    AppUser(
                        userName: cognitoUserName, cognito: cognito, token: cognitoUser.token,
                        user: $0)
                }
        }
    }
    return EventLoopFuture.whenAllSucceed(futures, on: eventLoop).map {
        (artist: artist, users: $0)
    }
    .flatMap { (artist, users) -> EventLoopFuture<Void> in
        let leader = users.first!
        let members = users[1...]

        let group = client.execute(
            CreateGroup.self,
            request: CreateGroup.Request(
                name: artist.name, englishName: artist.name,
                biography: "\(artist.name)として活動しています。(Imported from Spotify API)",
                since: Date(),
                artworkURL: URL(string: artist.bestQualityImage.url),
                twitterId: nil, youtubeChannelId: nil,
                hometown: nil
            ), as: leader)

        return group.flatMap { group in
            EventLoopFuture.andAllSucceed(
                members.map { member in
                    return client.execute(
                        InviteGroup.self, request: InviteGroup.Request(groupId: group.id),
                        as: leader
                    )
                    .flatMap { invitation in
                        client.execute(
                            JoinGroup.self, request: JoinGroup.Request(invitationId: invitation.id),
                            as: member)
                    }
                }, on: eventLoop)
        }
        .flatMap {
            EventLoopFuture.andAllSucceed(
                users.map { user in
                    cognito.destroyUser(userName: user.userName)
                }, on: eventLoop)
        }
    }

}

try! importSpotifyDataSoruces(eventLoop: eventLoopGroup.next())
