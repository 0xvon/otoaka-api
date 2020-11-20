import Domain
import NIO
import SNS

class SimpleNotificationService: PushNotificationService {
    let sns: SNS
    let platformApplicationArn: String
    let userRepository: UserRepository

    let eventLoop: EventLoop

    enum Error: Swift.Error {
        case endpointArnNotReturned
    }

    init(
        sns: SNS, platformApplicationArn: String,
        eventLoop: EventLoop,
        userRepository: UserRepository
    ) {
        self.sns = sns
        self.platformApplicationArn = platformApplicationArn
        self.userRepository = userRepository
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
