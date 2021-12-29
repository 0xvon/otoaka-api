import Domain
import FluentKit
import Foundation
import SQLKit

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
            message: request.message,
            isRealMoney: request.isRealMoney,
            groupId: group?.id,
            liveId: live?.id
        )
        try await tip.create(on: db)
        return try await Domain.SocialTip.translate(fromPersistance: tip, on: db)
    }
    
    public func get(page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip> {
        let tips = try await SocialTip.query(on: db)
            .sort(\.$thrownAt, .descending)
            .paginate(PageRequest(page: page, per: per))
        
        return try await Domain.Page<Domain.SocialTip>.translate(page: tips) { tip in
            try await Domain.SocialTip.translate(fromPersistance: tip, on: db)
        }
    }
    
    public func get(groupId: Domain.Group.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip> {
        let tips = try await SocialTip.query(on: db)
            .sort(\.$thrownAt, .descending)
            .filter(\.$group.$id == groupId.rawValue)
            .paginate(PageRequest(page: page, per: per))
        
        return try await Domain.Page<Domain.SocialTip>.translate(page: tips) { tip in
            try await Domain.SocialTip.translate(fromPersistance: tip, on: db)
        }
    }
    
    public func get(userId: Domain.User.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.SocialTip> {
        let tips = try await SocialTip.query(on: db)
            .sort(\.$thrownAt, .descending)
            .filter(\.$user.$id == userId.rawValue)
            .paginate(PageRequest(page: page, per: per))
        
        return try await Domain.Page<Domain.SocialTip>.translate(page: tips) { tip in
            try await Domain.SocialTip.translate(fromPersistance: tip, on: db)
        }
    }
    
    public func groupTipRanking(groupId: Domain.Group.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.UserTip> {
        var response: [Domain.UserTip] = []
        struct Tip: Codable {
            let user_id: UUID
            let tip_sum: Int
            let thrown_from: Date
        }
        
        if let mysql = db as? SQLDatabase {
            let tips = try await mysql.raw(
                """
                select sum(tip) as tip_sum, user_id, min(thrown_at) as thrown_from \
                from \(SocialTip.schema) \
                where group_id=UNHEX(REPLACE('\(groupId.rawValue.uuidString)', '-', '')) \
                group by user_id \
                order by tip_sum desc \
                limit \(String(per)) offset \(String((page - 1) * per))
                """
            ).all(decoding: Tip.self)
            
            for tip in tips {
                let user = try await Domain.User.translate(
                    fromPersistance: User.find(tip.user_id, on: db)!,
                    on: db
                ).get()
                response.append(Domain.UserTip(user: user, tip: tip.tip_sum, from: tip.thrown_from))
            }
        }
        return Domain.Page<UserTip>(
            items: response,
            metadata: PageMetadata(
                page: page, per: per, total: response.count
            )
        )
    }
    
    
    public func userTipRanking(userId: Domain.User.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.GroupTip> {
        var response: [Domain.GroupTip] = []
        struct Tip: Codable {
            let group_id: UUID
            let tip_sum: Int
            let thrown_from: Date
        }
        
        if let mysql = db as? SQLDatabase {
            let tips = try await mysql.raw(
                """
                select sum(tip) as tip_sum, group_id, min(thrown_at) as thrown_from \
                from \(SocialTip.schema) \
                where user_id=UNHEX(REPLACE('\(userId.rawValue.uuidString)', '-', '')) \
                group by group_id \
                order by tip_sum desc \
                limit \(String(per)) offset \(String((page - 1) * per))
                """
            ).all(decoding: Tip.self)
            
            for tip in tips {
                let group = try await Domain.Group.translate(
                    fromPersistance: Group.find(tip.group_id, on: db)!,
                    on: db
                ).get()
                response.append(Domain.GroupTip(group: group, tip: tip.tip_sum, from: tip.thrown_from))
            }
        }
        return Domain.Page<GroupTip>(
            items: response,
            metadata: PageMetadata(
                page: page, per: per, total: response.count
            )
        )
    }
}
