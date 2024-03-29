import Endpoint
import Foundation
import NIO

public protocol LiveRepository {
    func create(input: CreateLive.Request) -> EventLoopFuture<Live>
    func edit(id: Domain.Live.ID, input: EditLive.Request) -> EventLoopFuture<Domain.Live>
    func fetch(eventId: String, input: Endpoint.CreateLive.Request) async throws
    func merge(for live: Live.ID, lives: [Live.ID]) async throws
    func getLiveDetail(by id: Domain.Live.ID, selfUserId: Domain.User.ID) async throws
        -> Domain.LiveDetail
    func getLive(by id: Domain.Live.ID) -> EventLoopFuture<Domain.Live?>
    func getLive(by piaEventCode: String) -> EventLoopFuture<Domain.Live?>
    func getLive(title: String?, date: String?) -> EventLoopFuture<Domain.Live?>
    func getParticipants(liveId: Domain.Live.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.User>
    >
    func likedCount(liveId: Domain.Live.ID) async throws -> Int

    func reserveTicket(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<
        Void
    >
    func refundTicket(liveId: Domain.Live.ID, user: Domain.User.ID) async throws
    func updatePerformerStatus(
        requestId: PerformanceRequest.ID,
        status: PerformanceRequest.Status
    ) -> EventLoopFuture<Void>
    func find(requestId: PerformanceRequest.ID) -> EventLoopFuture<PerformanceRequest>
    func getUserTickets(
        userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int
    ) async throws -> Domain.Page<Domain.LiveFeed>

    func get(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<LiveFeed>>
    func get(selfUser: Domain.User.ID, page: Int, per: Int, group: Group.ID) async throws -> Page<
        LiveFeed
    >
    func getRequests(for user: Domain.User.ID, page: Int, per: Int) async throws -> Page<
        PerformanceRequest
    >
    func getPendingRequestCount(for user: Domain.User.ID) async throws -> Int
    func search(
        selfUser: Domain.User.ID, query: String?,
        groupId: Group.ID?,
        fromDate: String?, toDate: String?,
        page: Int, per: Int
    ) async throws -> Page<LiveFeed>
    func search(date: String) -> EventLoopFuture<[Domain.Live]>
    func getLatestLiveDate(by groupId: Domain.Group.ID) async throws -> Date?
    func getLivePosts(liveId: Domain.Live.ID, userId: Domain.User.ID, page: Int, per: Int)
        -> EventLoopFuture<Page<PostSummary>>
    func getMyLivePosts(liveId: Live.ID, userId: User.ID, page: Int, per: Int)
        -> EventLoopFuture<Page<PostSummary>>
}
