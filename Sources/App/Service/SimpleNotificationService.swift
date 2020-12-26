import Domain
import NIO
import SNS

class SimpleNotificationService: PushNotificationService {
    let sns: SNS
    let platformApplicationArn: String
    let userSocialRepository: UserSocialRepository
    let groupRepository: GroupRepository
    let userRepository: UserRepository

    let eventLoop: EventLoop

    enum Error: Swift.Error {
        case endpointArnNotReturned
    }

    convenience init(
        secrets: Secrets,
        userRepository: UserRepository,
        groupRepository: GroupRepository,
        userSocialRepository: UserSocialRepository,
        eventLoop: EventLoop
    ) {
        let sns = SNS(
            accessKeyId: secrets.awsAccessKeyId,
            secretAccessKey: secrets.awsSecretAccessKey,
            region: Region(rawValue: secrets.awsRegion),
            eventLoopGroupProvider: .shared(eventLoop)
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
    func publish(to user: User.ID, notification: PushNotification) -> EventLoopFuture<Void> {
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
            $0.map { sns.publish($0) }.flatten(on: eventLoop)
        }.map { _ in }
    }

    func publish(toArtistFollowers artist: User.ID, notification: PushNotification)
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

    func publish(toGroupFollowers group: Group.ID, notification: PushNotification)
        -> EventLoopFuture<Void>
    {
        let followers = userSocialRepository.followers(selfGroup: group)
        return followers.flatMap { followers in
            EventLoopFuture.andAllSucceed(
                followers.map { self.publish(to: $0, notification: notification) },
                on: self.eventLoop)
        }
    }

    func register(deviceToken: String, for user: User.ID) -> EventLoopFuture<Void> {
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
