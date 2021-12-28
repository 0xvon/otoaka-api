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
            let groupId = try req.content.decode(Group.ID.self)
            try await repository.entry(groupId: groupId)
            return Empty()
        })
    }
}
