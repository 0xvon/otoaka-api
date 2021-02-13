import AWSLambdaRuntime
import FluentKit
import Foundation
import NIO
import Persistance
import Service
import SotoCore

import struct Domain.PushNotification

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

class Handler: Lambda.Handler {
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
    func handle(context: Lambda.Context, event: ByteBuffer) -> EventLoopFuture<ByteBuffer?> {
        let db = databases.database(logger: context.logger, on: context.eventLoop)!
        let repository = Persistance.LiveRepository(db: db)
        let calendar = Calendar(identifier: .japanese)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let startOfTomorrow = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow)!
        let tickets = repository.getLiveTickets(until: startOfTomorrow)
        let userRepository = UserRepository(db: db)
        let groupRepository = GroupRepository(db: db)
        let userSocialRepository = UserSocialRepository(db: db)
        let notificationService = SimpleNotificationService(
            secrets: secrets,
            client: awsClient,
            userRepository: userRepository,
            groupRepository: groupRepository,
            userSocialRepository: userSocialRepository,
            eventLoop: context.eventLoop
        )
        return tickets.flatMapEach(on: context.eventLoop) { ticket -> EventLoopFuture<Void> in
            let notification = PushNotification(message: "\(ticket.live.title) は明日開催です")
            return notificationService.publish(to: ticket.user.id, notification: notification)
        }
        .transform(to: nil)
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
