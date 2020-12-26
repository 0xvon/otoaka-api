import Domain
import Persistance
import Vapor

func makePushNotificationService(request: Request) -> Domain.PushNotificationService {
    SimpleNotificationService(
        secrets: request.application.secrets,
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
