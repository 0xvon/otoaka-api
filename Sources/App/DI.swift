import Domain
import Persistance
import Service
import SotoCore
import Vapor

func makePushNotificationService(request: Request) -> Domain.PushNotificationService {
    SimpleNotificationService(
        secrets: request.application.secrets,
        client: request.application.awsClient,
        userRepository: makeUserRepository(request: request),
        groupRepository: makeGroupRepository(request: request),
        userSocialRepository: makeUserSocialRepository(request: request),
        eventLoop: request.eventLoop
    )
}

func makeGroupRepository(request: Request) -> Domain.GroupRepository {
    Persistance.GroupRepository(db: request.db)
}

func makeUserRepository(request: Request) -> Domain.UserRepository {
    Persistance.UserRepository(db: request.db)
}

func makeUserSocialRepository(request: Request) -> Domain.UserSocialRepository {
    Persistance.UserSocialRepository(db: request.db)
}

extension Application {
    struct AWSClientKey: StorageKey {
        typealias Value = AWSClient
    }
    var awsClient: AWSClient {
        get {
            guard let client = storage[AWSClientKey.self] else {
                fatalError("awsClient has been uninitialized")
            }
            return client
        }
        set {
            storage[AWSClientKey.self] = newValue
        }
    }
}
