//
//  ExternalController.swift
//  App
//
//  Created by Masato TSUTSUMI on 2021/04/25.
//

import Domain
import Endpoint
import Foundation
import Persistance
import Vapor
import XMLCoder

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.GroupRepository) throws -> T
)
    -> ((Request, URI) throws -> T)
{
    return { req, uri in
        let repository = Persistance.GroupRepository(db: req.db)
        return try handler(req, uri, repository)
    }
}

struct ExternalController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(endpoint: Endpoint.CreateGroupAsMaster.self, use: injectProvider { req, uri, repository in
            let groupRepository = Persistance.GroupRepository(db: req.db)
            let input = try req.content.decode(Endpoint.CreateGroup.Request.self)
            return groupRepository.create(input: input)
        })
        try routes.on(endpoint: Endpoint.BatchGroupUpdates.self, use: injectProvider(batchGroupInfo(req:uri:repository:)))
        try routes.on(endpoint: Endpoint.CheckGlobalIP.self, use: injectProvider { req, uri, repository in
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
            let res = req.client.get("https://ifconfig.me", headers: headers)
                
            return res
                .flatMapThrowing {
                    try $0.content.decode(CheckGlobalIP.Response.self)
                }
        })
        try routes.on(endpoint: ScanGroups.self, use: injectProvider { req, uri, repository in
            repository.get(page: 1, per: 1000).map { $0.items }
        })
        try routes.on(endpoint: CreateGroupFromBatch.self, use: injectProvider { req, uri, repository in
            let input = try req.content.decode(CreateGroup.Request.self)
            return repository.create(input: input)
        })
        try routes.on(endpoint: FetchLive.self, use: injectProvider { req, uri, repository in
            let input = try req.content.decode(CreateLive.Request.self)
            let liveRepository = LiveRepository(db: req.db)
            let notificationService = makePushNotificationService(request: req)
            let useCase = FetchLiveUseCase(liveRepository: liveRepository, notificationService: notificationService, eventLoop: req.eventLoop)
            return try useCase(input)
        })
        try routes.on(endpoint: ExtCreateLive.self, use: injectProvider { req, uri, repository in
            let input = try req.content.decode(CreateLive.Request.self)
            let liveRepository = LiveRepository(db: req.db)
            return liveRepository.create(input: input)
        })
        try routes.on(endpoint: Endpoint.TestGetPiaArtist.self, use: injectProvider { req, uri, repository in
            var reqUri = PiaSearchArtists.URI()
            reqUri.apikey = uri.piaApiKey
            reqUri.keyword = uri.keyword
            reqUri.get_count = 10
            let path = try! reqUri.encode(baseURL: URL(string:"http://search-api.pia.jp")!).absoluteString
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: HTTPMediaType.xml.serialize())
            headers.add(name: "End-User-Agent", value: "N252i DoCoMo/1.0/N252i/c10/TB/W22H10")
            let res = req.client.get(URI(string: path), headers: headers)
            return res
                .flatMapThrowing {
                    return try! XMLDecoder().decode(TestGetPiaArtist.Response.self, from: Data(buffer: $0.body!))
                }            
        })
        try routes.on(endpoint: Endpoint.TestGetPiaEventRelease.self, use: injectProvider { req, uri, repository in
            var reqUri = PiaSearchEventReleasesBriefly.URI()
            reqUri.apikey = uri.piaApiKey
            reqUri.keyword = uri.keyword
            reqUri.get_count = 10
            let path = try! reqUri.encode(baseURL: URL(string:"http://search-api.pia.jp")!).absoluteString
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: HTTPMediaType.xml.serialize())
            headers.add(name: "End-User-Agent", value: "N252i DoCoMo/1.0/N252i/c10/TB/W22H10")
            let res = req.client.get(URI(string: path), headers: headers)
            return res
                .flatMapThrowing {
                    print($0)
                    return try! XMLDecoder().decode(TestGetPiaEventRelease.Response.self, from: Data(buffer: $0.body!))
                }
        })
    }
    
    func batchGroupInfo(req: Request, uri: BatchGroupUpdates.URI, repository: Domain.GroupRepository) throws -> EventLoopFuture<Empty> {
        let groupRepo = Persistance.GroupRepository(db: req.db)
        let userSocialRepo = Persistance.UserSocialRepository(db: req.db)
        let notificationService = makePushNotificationService(request: req)
        let groups = groupRepo.followedGroups()
        
        return groups.flatMapThrowing { groups in
            groups.forEach { group in
                if let channelId = group.youtubeChannelId {
                    var uri = Endpoint.ListChannel.URI()
                    uri.channelId = channelId
                    uri.order = "date"
                    uri.part = "snippet"
                    uri.maxResults = 1
                    uri.type = "video"
                    let path = URI(path: try! uri.encode(baseURL: URL(string: "https://www.googleapis.com")!).absoluteString)
                    var headers = HTTPHeaders()
                    headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
                    _ = req.client.get(path, headers: headers) { res in
                        let body = try res.content.decode(ListChannel.Response.self)
                        if let firstItem = body.items.first {
                            let followers = userSocialRepo.followers(selfGroup: group.id)
                            _ = followers.flatMapThrowing { followers in
                                followers.forEach { follower in
                                    let notification = PushNotification(message: "\(group.name)のYouTubeが更新されました")
                                    _ = notificationService.publish(to: follower, notification: notification)
                                    _ = groupRepo.updateYouTube(item: firstItem, to: follower)
                                }
                            }
                        }
                    }
                }
            }
        }
        .map { Empty() }
    }
}

extension PiaSearchArtists.Response: Content {}

extension PiaSearchEventReleasesBriefly.Response: Content {}
