import NIO
import StubKit
import XCTest

@testable import Domain

private func makeArtist() -> User {
    try! Stub.make(User.self) {
        $0.set(\.role, value: .artist(try! Stub.make()))
    }
}

private func makeFan() -> User {
    try! Stub.make(User.self) {
        $0.set(\.role, value: .fan(try! Stub.make()))
    }
}

enum Expect<Success> {
    case success((Success) throws -> Void)
    case failure((Error) throws -> Void)

    func receive<E>(result: Result<Success, E>) throws {
        switch (self, result) {
        case (let .success(matcher), let .success(value)):
            try matcher(value)
        case (let .failure(matcher), let .failure(error)):
            try matcher(error)
        case (.failure(_), .success(_)):
            XCTFail("expect failure but got success")
        case (.success(_), .failure(_)):
            XCTFail("expect success but got failure")
        }
    }
}

class CreateLiveUseCaseTests: XCTestCase {
    func testCreateOneman() throws {
        class Mock: GroupRepositoryMock, LiveRepositoryMock {
            let eventLoop: EventLoop
            let memberships: [Group.ID: [User.ID]]

            func isMember(of groupId: Group.ID, member: User.ID) -> EventLoopFuture<Bool> {
                eventLoop.makeSucceededFuture(memberships[groupId]?.contains(member) ?? false)
            }
            var createdLives: [Live] = []
            func create(input: CreateLive.Request, authorId: User.ID) -> EventLoopFuture<Live> {
                let live = try! Stub.make(Live.self) {
                    $0.set(\.author.id, value: authorId)
                }
                createdLives.append(live)
                return eventLoop.makeSucceededFuture(live)
            }

            init(eventLoop: EventLoop, memberships: [Group.ID: [User.ID]]) {
                self.eventLoop = eventLoop
                self.memberships = memberships
            }
        }

        let groupX = try! Stub.make(Group.self)
        let groupY = try! Stub.make(Group.self)
        let artistA = makeArtist()
        let artistB = makeArtist()
        let artistC = makeArtist()
        let fanD = makeFan()

        let memberships: [Group.ID: [User.ID]] = [
            groupX.id: [artistA.id, artistB.id],
            groupY.id: [artistB.id, artistC.id],
        ]

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let repositoryLoop = eventLoopGroup.next()
        var mock = Mock(eventLoop: repositoryLoop, memberships: memberships)

        typealias Input = (
            request: CreateLiveUseCase.Request,
            expect: Expect<CreateLiveUseCase.Response>
        )

        let inputs: [Input] = try! [
            (
                request: (
                    user: artistA,
                    input: Stub.make {
                        $0.set(\.style, value: LiveStyle.oneman(performer: groupX.id))
                        $0.set(\.hostGroupId, value: groupX.id)
                    }
                ),
                expect: .success { _ in
                    let live = try XCTUnwrap(mock.createdLives.first)
                    XCTAssertEqual(live.author.id, artistA.id)
                }
            ),
            (
                request: (
                    user: artistC,
                    input: Stub.make {
                        $0.set(\.style, value: LiveStyle.oneman(performer: groupX.id))
                        $0.set(\.hostGroupId, value: groupX.id)
                    }
                ),
                expect: .failure { error in
                    let error = try XCTUnwrap(error as? CreateLiveUseCase.Error)
                    XCTAssertEqual(error, .isNotMemberOfHostGroup)
                }
            ),
            (
                request: (
                    user: fanD,
                    input: Stub.make {
                        $0.set(\.style, value: LiveStyle.oneman(performer: groupX.id))
                        $0.set(\.hostGroupId, value: groupX.id)
                    }
                ),
                expect: .failure { error in
                    let error = try XCTUnwrap(error as? CreateLiveUseCase.Error)
                    XCTAssertEqual(error, .fanCannotCreateLive)
                }
            ),
        ]

        for input in inputs {
            let useCase = CreateLiveUseCase(
                groupRepository: mock, liveRepository: mock,
                eventLoop: eventLoopGroup.next())
            let response = Result { try useCase(input.request).wait() }
            try input.expect.receive(result: response)
            mock = Mock(eventLoop: repositoryLoop, memberships: memberships)
        }
    }
}
