import Domain
import FluentKit
import Foundation

public class SocialTipRepository: Domain.SocialTipRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }
    
    public func send(userId: Domain.User.ID, request: SendSocialTip.Request) async throws -> Domain.SocialTip {
        let type: SocialTipType
        var group: Domain.Group?
        var live: Domain.Live?
        switch request.type {
        case .group(let item):
            type = .group
            group = item
        case .live(let item):
            type = .live
            live = item
        }
        
        let tip = SocialTip(
            tip: request.tip,
            userId: userId,
            type: type,
            groupId: group?.id,
            liveId: live?.id
        )
        try await tip.create(on: db)
        return try await Domain.SocialTip.translate(fromPersistance: tip, on: db)
    }
    
    public func get(page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip> {
        let tips = try await SocialTip.query(on: db)
            .with(\.$user)
            .with(\.$group)
            .with(\.$live)
            .sort(\.$thrownAt, .descending)
            .paginate(PageRequest(page: page, per: per))
        
        return try await Domain.Page<Domain.SocialTip>.translate(page: tips) { tip in
            try await Domain.SocialTip.translate(fromPersistance: tip, on: db)
        }
    }
    
    public func get(groupId: Domain.Group.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip> {
        let tips = try await SocialTip.query(on: db)
            .with(\.$user)
            .with(\.$group)
            .with(\.$live)
            .sort(\.$thrownAt, .descending)
            .filter(\.$group.$id == groupId.rawValue)
            .paginate(PageRequest(page: page, per: per))
        
        return try await Domain.Page<Domain.SocialTip>.translate(page: tips) { tip in
            try await Domain.SocialTip.translate(fromPersistance: tip, on: db)
        }
    }
    
    public func get(userId: Domain.User.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip> {
        let tips = try await SocialTip.query(on: db)
            .with(\.$user)
            .with(\.$group)
            .with(\.$live)
            .sort(\.$thrownAt, .descending)
            .filter(\.$user.$id == userId.rawValue)
            .paginate(PageRequest(page: page, per: per))
        
        return try await Domain.Page<Domain.SocialTip>.translate(page: tips) { tip in
            try await Domain.SocialTip.translate(fromPersistance: tip, on: db)
        }
    }
}
