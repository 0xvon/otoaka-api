import AWSLambdaRuntime
import FluentKit
import Foundation
import NIO
import Persistance
import Service
import SotoCore

import struct Domain.PushNotification
import struct Domain.User

struct EnvironmentSecrets: DatabaseSecrets, SimpleNotificationServiceSecrets {
    init() {
        func require(_ key: String) -> String {
            guard let value = ProcessInfo.processInfo.environment[key] else {
                fatalError("Please set \"\(key)\" environment variable")
            }
            return value
        }
        self.awsAccessKeyId = require("AWS_ACCESS_KEY_ID")
        self.awsSecretAccessKey = require("AWS_SECRET_ACCESS_KEY")
        self.awsRegion = require("AWS_REGION")
        self.snsPlatformApplicationArn = require("SNS_PLATFORM_APPLICATION_ARN")
        self.databaseURL = require("DATABASE_URL")
    }
    let awsAccessKeyId: String
    let awsSecretAccessKey: String
    let awsRegion: String
    let snsPlatformApplicationArn: String
    let databaseURL: String
}

let secrets = EnvironmentSecrets()

protocol UserListProvider {
    func provide() -> EventLoopFuture<[User]>
}

struct AllUserSegment: UserListProvider {
    let repository: UserRepository
    func provide() -> EventLoopFuture<[User]> {
        repository.all()
    }
}

enum UserSegment: String, Codable {
    case all
}

class Handler: EventLoopLambdaHandler {
    struct In: Codable {
        let message: String
        let segment: UserSegment
    }
    typealias Out = Void

    let databases: Databases
    let awsClient: AWSClient
    init(context: Lambda.InitializationContext) throws {
        databases = Databases(threadPool: NIOThreadPool(numberOfThreads: 1), on: context.eventLoop)
        awsClient = AWSClient(
            credentialProvider: .static(accessKeyId: secrets.awsAccessKeyId, secretAccessKey: secrets.awsSecretAccessKey),
            httpClientProvider: .createNew
        )
        try Persistance.setup(
            databases: databases,
            secrets: secrets
        )
    }
    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Void> {
        let db = databases.database(logger: context.logger, on: context.eventLoop)!
        let userRepository = UserRepository(db: db)
        let groupRepository = GroupRepository(db: db)
        let userSocialRepository = UserSocialRepository(db: db)

        let userListProvider: UserListProvider
        switch event.segment {
        case .all:
            userListProvider = AllUserSegment(repository: userRepository)
        }
        let notificationService = SimpleNotificationService(
            secrets: secrets,
            client: awsClient,
            userRepository: userRepository,
            groupRepository: groupRepository,
            userSocialRepository: userSocialRepository,
            eventLoop: context.eventLoop
        )

        return userListProvider.provide().flatMapEach(on: context.eventLoop) {
            user -> EventLoopFuture<Void> in
            let notification = PushNotification(message: event.message)
            return notificationService.publish(to: user.id, notification: notification)
        }
        .transform(to: ())
    }

    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        let promise = context.eventLoop.makePromise(of: Void.self)
        awsClient.shutdown { error in
            if let error = error {
                promise.completeWith(.failure(error))
            } else {
                promise.completeWith(.success(()))
            }
        }
        return promise.futureResult
    }
}

Lambda.run { (context) -> EventLoopFuture<Lambda.Handler> in
    context.eventLoop.submit {
        try Handler(context: context)
    }
}
