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

    public init(
        liveRepository: LiveRepository, notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.liveRepository = liveRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) async throws -> Response {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            return dateFormatter
        }()
        let date = Date()
        let tomorrow = date.addingTimeInterval(60 * 60 * 24)

        let lives = try await liveRepository.search(date: dateFormatter.string(from: tomorrow))
            .get()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for live in lives {
                group.addTask {
                    let notification = PushNotification(message: "\(live.title)の前日です")
                    try await notificationService.publish(
                        toLiveLikedUsers: live.id, notification: notification
                    ).get()
                }
            }
            try await group.waitForAll()
        }
        return "ok"
    }
}

public struct NotifyPastLivesUseCase: UseCase {
    public typealias Request = Empty
    public typealias Response = String

    public let liveRepository: LiveRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        liveRepository: LiveRepository, notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.liveRepository = liveRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) async throws -> Response {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            return dateFormatter
        }()
        let date = Date()

        let lives = try await liveRepository.search(date: dateFormatter.string(from: date)).get()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for live in lives {
                group.addTask {
                    let notification = PushNotification(
                        message: "\(live.title)の感想を書こう！行けなかった人はみんなの感想を見て一緒に余韻に浸ろう！")
                    try await notificationService.publish(
                        toLiveLikedUsers: live.id, notification: notification
                    ).get()
                }
            }
            try await group.waitForAll()
        }
        return "ok"
    }
}

public struct SendNotificationUseCase: UseCase {
    public typealias Request = SendNotification.Request
    public typealias Response = SendNotification.Response

    public let repository: UserRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        repository: UserRepository, notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.repository = repository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) async throws -> Response {
        var users: [User]
        switch request.segment {
        case .all:
            users = try await repository.all().get()
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for user in users {
                group.addTask {
                    try await notificationService.publish(
                        to: user.id, notification: PushNotification(message: request.message)
                    ).get()
                }
            }
            try await group.waitForAll()
        }
        return "ok"
    }
}
