import NIO

public struct PushNotification {
    public let message: String
}

public protocol PushNotificationService {
    func publish(to user: User.ID, notification: PushNotification) -> EventLoopFuture<Void>
    func register(deviceToken: String, for user: User.ID) -> EventLoopFuture<Void>
}
