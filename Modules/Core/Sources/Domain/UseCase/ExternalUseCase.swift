//
//  ExternalUseCase.swift
//  Domain
//
//  Created by Masato TSUTSUMI on 2021/10/09.
//

import Foundation
import NIO

public struct NotifyUpcomingLivesUseCase: UseCase {
    public typealias Request = Empty
    public typealias Response = String
    
    public let liveRepository: LiveRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop
    
    public init(liveRepository: LiveRepository, notificationService: PushNotificationService, eventLoop: EventLoop) {
        self.liveRepository = liveRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }
    
    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            return dateFormatter
        }()
        let date = Date()
        let tomorrow = date.addingTimeInterval(60 * 60 * 24)
        
        let lives = liveRepository.search(date: dateFormatter.string(from: tomorrow))
        return lives.flatMap { lives -> EventLoopFuture<Void> in
            return EventLoopFuture<Void>.andAllSucceed(lives.map {
                notificationService.publish(toLiveLikedUsers: $0.id, notification: PushNotification(message: "\($0.title)の前日です")
                )
            }, on: eventLoop)
        }
        .map { "ok" }
    }
}

public struct NotifyPastLivesUseCase: UseCase {
    public typealias Request = Empty
    public typealias Response = String
    
    public let liveRepository: LiveRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop
    
    public init(liveRepository: LiveRepository, notificationService: PushNotificationService, eventLoop: EventLoop) {
        self.liveRepository = liveRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }
    
    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            return dateFormatter
        }()
        let date = Date()
        
        let lives = liveRepository.search(date: dateFormatter.string(from: date))
        return lives.flatMap { lives -> EventLoopFuture<Void> in
            return EventLoopFuture<Void>.andAllSucceed(lives.map {
                notificationService.publish(toLiveLikedUsers: $0.id, notification: PushNotification(message: "\($0.title)の感想を書こう！行けなかった人はみんなの感想を見て一緒に余韻に浸ろう！")
                )
            }, on: eventLoop)
        }
        .map { "ok" }
    }
}

public struct SendNotificationUseCase: UseCase {
    public typealias Request = SendNotification.Request
    public typealias Response = SendNotification.Response
    
    public let repository: UserRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop
    
    public init(repository: UserRepository, notificationService: PushNotificationService, eventLoop: EventLoop) {
        self.repository = repository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }
    
    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        var users: EventLoopFuture<[User]>
        switch request.segment {
        case .all:
            users = repository.all()
        }
        
        return users.flatMap { users -> EventLoopFuture<Void> in
            return EventLoopFuture<Void>.andAllSucceed(users.map {
                notificationService.publish(to: $0.id, notification: PushNotification(message: request.message))
            }, on: eventLoop)
        }
        .map { "ok" }
    }
}
