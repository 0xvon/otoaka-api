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
        try routes.on(endpoint: Endpoint.CheckGlobalIP.self, use: injectProvider { req, uri, repository in
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
            let res = req.client.get("https://ifconfig.me", headers: headers)
                
            return res
                .flatMapThrowing {
                    try $0.content.decode(CheckGlobalIP.Response.self)
                }
        })
        try routes.on(endpoint: Endpoint.NotifyUpcomingLives.self, use: injectProvider { req, uri, repository in
            let liveRepository = Persistance.LiveRepository(db: req.db)
            let notificationService = makePushNotificationService(request: req)
            let useCase = NotifyUpcomingLivesUseCase(liveRepository: liveRepository, notificationService: notificationService, eventLoop: req.eventLoop)
            return try useCase(Empty())
        })
        try routes.on(endpoint: Endpoint.SendNotification.self, use: injectProvider { req, uri, repository in
            let userRepository = Persistance.UserRepository(db: req.db)
            let notificationService = makePushNotificationService(request: req)
            let input = try req.content.decode(Endpoint.SendNotification.Request.self)
            let useCase = SendNotificationUseCase(repository: userRepository, notificationService: notificationService, eventLoop: req.eventLoop)
            return try useCase(input)
        })
        try routes.on(endpoint: Endpoint.NotifyPastLives.self, use: injectProvider { req, uri, repository in
            let liveRepository = Persistance.LiveRepository(db: req.db)
            let notificationService = makePushNotificationService(request: req)
            let useCase = NotifyPastLivesUseCase(liveRepository: liveRepository, notificationService: notificationService, eventLoop: req.eventLoop)
            return try useCase(Empty())
        })
        try routes.on(endpoint: ScanGroups.self, use: injectProvider { req, uri, repository in
            repository.get(page: 1, per: 1000).map { $0.items }
        })
    }
}
