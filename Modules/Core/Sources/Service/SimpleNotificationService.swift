import Domain
import NIO
import SotoSNS
import Logging

public protocol SimpleNotificationServiceSecrets {
    var awsAccessKeyId: String { get }
    var awsSecretAccessKey: String { get }
    var awsRegion: String { get }
    var snsPlatformApplicationArn: String { get }
}

public class SimpleNotificationService: PushNotificationService {
    let sns: SNS
    let platformApplicationArn: String
    let userSocialRepository: UserSocialRepository
    let groupRepository: GroupRepository
    let userRepository: UserRepository

    let eventLoop: EventLoop
    let logger = Logger(label: "simple-notification-service-logger")

    enum Error: Swift.Error {
        case endpointArnNotReturned
    }

    public convenience init(
        secrets: SimpleNotificationServiceSecrets,
        client: AWSClient,
        userRepository: UserRepository,
        groupRepository: GroupRepository,
        userSocialRepository: UserSocialRepository,
        eventLoop: EventLoop
    ) {
        let sns = SNS(
            client: client,
            region: Region(rawValue: secrets.awsRegion)
        )
        self.init(
            sns: sns, platformApplicationArn: secrets.snsPlatformApplicationArn,
            eventLoop: eventLoop, userRepository: userRepository,
            groupRepository: groupRepository,
            userSocialRepository: userSocialRepository
        )
    }
    init(
        sns: SNS, platformApplicationArn: String,
        eventLoop: EventLoop,
        userRepository: UserRepository, groupRepository: GroupRepository,
        userSocialRepository: UserSocialRepository
    ) {
        self.sns = sns
        self.platformApplicationArn = platformApplicationArn
        self.userRepository = userRepository
        self.groupRepository = groupRepository
        self.userSocialRepository = userSocialRepository
        self.eventLoop = eventLoop
    }
    public func publish(to user: User.ID, notification: PushNotification) -> EventLoopFuture<Void> {
        // FIXME: Use topic intead of multicast to endpoints?
        let endpointArms = userRepository.endpointArns(for: user)
        let input = endpointArms.map {
            $0.map {
                SNS.PublishInput(
                    message: notification.message,
                    targetArn: $0
                )
            }
        }
        return input.flatMap { [sns, eventLoop] in
            EventLoopFuture.andAllSucceed($0.map { sns.publish($0) }, on: eventLoop)
        }.map { _ in }
        .flatMapError { [logger, eventLoop] error in
            logger.error(Logger.Message(stringLiteral: String(describing: error)))
            return eventLoop.makeSucceededFuture(())
        }
    }

    public func publish(toArtistFollowers artist: User.ID, notification: PushNotification)
        -> EventLoopFuture<Void>
    {
        let groups = groupRepository.getMemberships(for: artist)
        let followers = groups.flatMap { groups in
            EventLoopFuture.whenAllSucceed(
                groups.map {
                    self.userSocialRepository.followers(selfGroup: $0.id)
                }, on: self.eventLoop)
        }
        .map { Set($0.flatMap { $0 }) }

        return followers.flatMap { followers in
            EventLoopFuture.andAllSucceed(
                followers.map { self.publish(to: $0, notification: notification) },
                on: self.eventLoop)
        }
    }

    public func publish(toGroupFollowers group: Group.ID, notification: PushNotification)
        -> EventLoopFuture<Void>
    {
        let followers = userSocialRepository.followers(selfGroup: group)
        return followers.flatMap { followers in
            EventLoopFuture.andAllSucceed(
                followers.map { self.publish(to: $0, notification: notification) },
                on: self.eventLoop)
        }
    }

    public func register(deviceToken: String, for user: User.ID) -> EventLoopFuture<Void> {
        let input = SNS.CreatePlatformEndpointInput(
            platformApplicationArn: platformApplicationArn, token: deviceToken
        )
        return sns.createPlatformEndpoint(input)
            .map(\.endpointArn).unwrap(orError: Error.endpointArnNotReturned)
            .flatMap { [userRepository] in
                userRepository.setEndpointArn($0, for: user)
            }
    }
}
