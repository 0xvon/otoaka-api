import NIO
import Endpoint
import DomainEntity

public protocol SocialTipRepository {
    func send(
        userId: Domain.User.ID, request: SendSocialTip.Request
    ) async throws -> Domain.SocialTip
    func get(page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip>
    func get(groupId: Domain.Group.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip>
    func get(userId: Domain.User.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip>
    func high(page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip>
    func groupTipRanking(groupId: Group.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.UserTip>
    func userTipRanking(userId: User.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.GroupTip>
    func socialTippableGroups() async throws -> [Domain.Group]
    func userTipFeed(page: Int, per: Int) async throws -> Domain.Page<Domain.UserTip>
    func groupTipFeed(page: Int, per: Int) async throws -> Domain.Page<Domain.GroupTip>
    func events(page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTipEvent>
    func createEvent(request: CreateSocialTipEvent.Request) async throws -> Domain.SocialTipEvent
}
