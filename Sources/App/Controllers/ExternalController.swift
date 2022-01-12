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
import Kanna

struct ExternalController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(
            endpoint: Endpoint.CheckGlobalIP.self,
            use: { req, uri in
                var headers = HTTPHeaders()
                headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
                let res = try await req.client.get("https://ifconfig.me", headers: headers)
                return try res.content.decode(CheckGlobalIP.Response.self)
            })
        try routes.on(
            endpoint: Endpoint.NotifyUpcomingLives.self,
            use: { req, uri in
                let liveRepository = Persistance.LiveRepository(db: req.db)
                let notificationService = makePushNotificationService(request: req)
                let useCase = NotifyUpcomingLivesUseCase(
                    liveRepository: liveRepository, notificationService: notificationService,
                    eventLoop: req.eventLoop)
                return try await useCase(Empty())
            })
        try routes.on(
            endpoint: Endpoint.SendNotification.self,
            use: { req, uri in
                let userRepository = Persistance.UserRepository(db: req.db)
                let notificationService = makePushNotificationService(request: req)
                let input = try req.content.decode(Endpoint.SendNotification.Request.self)
                let useCase = SendNotificationUseCase(
                    repository: userRepository, notificationService: notificationService,
                    eventLoop: req.eventLoop)
                return try await useCase(input)
            })
        try routes.on(
            endpoint: Endpoint.NotifyPastLives.self,
            use: { req, uri in
                let liveRepository = Persistance.LiveRepository(db: req.db)
                let notificationService = makePushNotificationService(request: req)
                let useCase = NotifyPastLivesUseCase(
                    liveRepository: liveRepository, notificationService: notificationService,
                    eventLoop: req.eventLoop)
                return try await useCase(Empty())
            })
        try routes.on(
            endpoint: ScanGroups.self,
            use: { req, uri in
                let repository = Persistance.GroupRepository(db: req.db)
                let page = try await repository.get(page: 1, per: 1000).get()
                return page.items
            })
        try routes.on(endpoint: EntryGroup.self, use: { req, uri in
            let repository = Persistance.GroupRepository(db: req.db)
            let req = try req.content.decode(EntryGroup.Request.self)
            try await repository.entry(groupId: req.groupId)
            return Empty()
        })
        try routes.on(endpoint: Endpoint.FetchLive.self, use: { req, uri in
            let input = try req.content.decode(Endpoint.FetchLive.Request.self)
            let user = try req.auth.require(Domain.User.self)
            let groupRepository = Persistance.GroupRepository(db: req.db)
            let liveRepository = Persistance.LiveRepository(db: req.db)
            let notificationService = makePushNotificationService(request: req)
            
            guard let group = try await groupRepository.search(name: input.name).get() else {
                throw Error.artistNotFound
            }
            
            // search artist
            let artistId = try await searchArtist(req: req, groupName: input.name)
            
            // search lives
            var liveIds: [String] = []
            var page = 1
            while(true) {
                let ids = try await searchLives(req: req, artistId: artistId, page: page, from: input.from)
                if ids.isEmpty { break }
                liveIds += ids
                page += 1
            }
            
            print(liveIds)
            // get and create live
            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                for live in liveIds {
                    let request = try await getLiveInfo(req: req, liveId: live, group: group)
                    print(request)
                    let useCase = CreateLiveUseCase(
                        groupRepository: groupRepository,
                        liveRepository: liveRepository,
                        notificationService: notificationService,
                        eventLoop: req.eventLoop
                    )
                    _ = try await useCase((user: user, input: request))
                }
                try await taskGroup.waitForAll()
            }
            
            return Empty()
        })
    }
    
    // アーティスト名からartistIdを取得
    func searchArtist(
        req: Request, groupName: String
    ) async throws -> String {
        let name = groupName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let path = "/search?keyword=\(name)&genre=all&option=6"
        let html = try await requestLiveFansHtml(req: req, subPath: path)
        guard let groupId = html.body?.css("div.artistBox a").first?["href"]?
                .components(separatedBy: "/").last else {
            throw Error.artistNotFound
        }
        return groupId
    }
    
    // artistIdからliveId一覧を取得
    func searchLives(
        req: Request, artistId: String, page: Int = 1, from: Date
    ) async throws -> [String] {
        let path = "/search/artist/\(artistId)/page:\(page)?sort=e1"
        let html = try await requestLiveFansHtml(req: req, subPath: path)
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            return dateFormatter
        }()
        if let latestDate = html.body?.css("p.date").first?.text?
            .components(separatedBy: " ").first.flatMap(dateFormatter.date(from:)) {
            if latestDate < from { return [] }
        }
        
        let liveIds = html.body?.css("h3.artistName a")
            .compactMap {
            $0["href"]?.components(separatedBy: "/").last
        }
        return liveIds ?? []
    }
    
    // liveIdからライブ情報を取得
    func getLiveInfo(
        req: Request, liveId: String, group: Group
    ) async throws -> Endpoint.CreateLive.Request {
        let path = "/events/\(liveId)"
        let html = try await requestLiveFansHtml(req: req, subPath: path)
        let title = html.body?.css("h4.liveName2").first?.text
        let livehouse = html.body?.css("address").first?.text?
            .replacingOccurrences(of: "＠", with: "")
            .components(separatedBy: " (").first?
            .components(separatedBy: " at ").last
        let date = html.body?.css("p.date").first?.text?
            .components(separatedBy: " ").first?
            .replacingOccurrences(of: "/", with: "")
        return Endpoint.CreateLive.Request(
            title: title ?? group.name,
            style: .oneman(performer: group.id),
            price: 5000,
            artworkURL: group.artworkURL,
            hostGroupId: group.id,
            liveHouse: livehouse,
            date: date,
            endDate: nil,
            openAt: "17:00",
            startAt: "18:00",
            piaEventCode: nil,
            piaReleaseUrl: nil,
            piaEventUrl: nil
        )
    }
    
    func requestLiveFansHtml(req: Request, subPath: String) async throws -> HTMLDocument {
        let baseUrl = "https://www.livefans.jp"
        let path = baseUrl + subPath
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: HTTPMediaType.html.serialize())
        let res = try await req.client.get(URI(string: path), headers: headers)
        let document = String(buffer: res.body!)
        let html = try HTML(html: document, encoding: .utf8)
        return html
    }
    
    enum Error: Swift.Error {
        case artistNotFound
    }
}
