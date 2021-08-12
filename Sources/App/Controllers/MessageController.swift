import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.MessageRepository) throws -> T
)
    -> ((Request, URI) throws -> T)
{
    return { req, uri in
        let repository = Persistance.MessageRepository(db: req.db)
        return try handler(req, uri, repository)
    }
}

struct MessageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(
            endpoint: Endpoint.CreateMessageRoom.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(Endpoint.CreateMessageRoom.Request.self)
                return repository.createRoom(selfUser: user.id, input: input)
            })
        
        try routes.on(
            endpoint: Endpoint.DeleteMessageRoom.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(Endpoint.DeleteMessageRoom.Request.self)
                return repository.deleteRoom(selfUser: user.id, roomId: input.roomId)
                    .map { Empty() }
            })
        
        try routes.on(
            endpoint: Endpoint.GetRooms.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.rooms(selfUser: user.id, page: uri.page, per: uri.per)
            }
        )
        
        try routes.on(
            endpoint: OpenRoomMessages.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.open(selfUser: user.id, roomId: uri.roomId, page: uri.page, per: uri.per)
            })
        
        try routes.on(
            endpoint: Endpoint.SendMessage.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(Endpoint.SendMessage.Request.self)
                let notificationService = makePushNotificationService(request: req)
                return repository.send(selfUser: user.id, input: input)
                    .flatMap { message in
                        let notification = PushNotification(message: "\(user.name)からメッセージが届きました")
                        return repository.getRoomMember(selfUser: user.id, roomId: message.roomId)
                            .flatMapEach(on: req.eventLoop) { member in
                                return notificationService.publish(to: member.id, notification: notification)
                            }
                            .map { _ in message }
                    }
                
            })
    }
}

extension Persistance.MessageRepository.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .alreadyCreated: return .badRequest
        case .alreadyDeleted: return .badRequest
        case .roomNotFound: return .badRequest
        case .userNotFound: return .badRequest
        case .messageNotFound: return .badRequest
        }
    }
}

extension Endpoint.MessageRoom: Content {}

extension Endpoint.Message: Content {}
