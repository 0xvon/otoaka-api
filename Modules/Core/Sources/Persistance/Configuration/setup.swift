//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import FluentKit
import FluentMySQLDriver

public protocol DatabaseSecrets {
    var databaseURL: String { get }
}

// configures persistance system
public func setup(
    databases: Databases,
    secrets: DatabaseSecrets
) throws {
    guard let databaseURL = URL(string: secrets.databaseURL),
        let config = MySQLConfiguration.certificateVerificationDisabled(url: databaseURL)
    else {
        fatalError("Invalid database url: \(secrets.databaseURL)")
    }
    databases.use(
        .mysql(configuration: config, connectionPoolTimeout: .minutes(1)), as: .mysql,
        isDefault: true)

}

public func setupMigration(
    migrator: Migrator,
    migrations: Migrations
) throws {
    migrations.add([
        CreateUser(),
        CreateGroup(), CreateMembership(), CreateGroupInvitation(),
        CreateLive(), CreateLivePerformer(), CreatePerformanceRequest(),
        CreateTicket(), CreateFollowing(), CreateUserDevice(),
        CreateLiveLike(), CreateGroupFeed(), CreateArtistFeedComment(),
        AddDeletedAtFieldToGroup(), AddDeletedAtFieldToArtistFeed(),
        CognitoSubToUsername(), CreateUserFollowing(),
        CreateUserFeed(), CreateUserFeedComment(),
        CreateUserFeedLike(),
        ThumbnailUrlAndAppleMusicToArtistFeed(), ThumbnailUrlAndAppleMusicToUserFeed(),
        InstagramAndTwitterUrlToUser(),
        CreateUserNotification(),

        CreatePost(), CreatePostTrack(),
        CreatePostImageUrl(), CreatePostLike(),
        CreatePostComment(), CreatePostGroup(),
        AddPostOnUserNotification(),

        MoreInfoToUser(),
        CreateUserBlocking(),

        CreateMessageRoom(), CreateMessageRoomMember(),
        CreateMessage(), CreateMessageReading(),
        AddMessageRoomToLatestMessageAt(),

        UpdateLiveForPia(), AssociatePostWithLive(),
        UpdateLiveForDateTerm(),

        CreateRecentlyFollowing(),

        CreateUsername(),
        
        CreateSocialTip(), CreateGroupEntry(),
        UpdateSocialTipToMessageAndIsRealMoney(), CreatePoint(),
        
        CreateSocialTipEvent(),

        AddIndexToLives(), UpdateSocialTipToTheme(),
        
        AddGroupCreatedAt(), AddUserCreatedAt(),
        AddFollowingCreatedAt(), AddLiveLikeCreatedAt(),
        AddLivePerformerCreatedAt(), AddPointCreatedAt(),
        AddRecentlyFollowingCreatedAt(), AddUserBlockingCreatedAt(),
        AddUserFollowingCreatedAt(), AddUsernameCreatedAt(),
        
        addPostToIsPrivate(),
    ])

    try migrator.setupIfNeeded().flatMap {
        migrator.prepareBatch()
    }.wait()
}

extension MySQLConfiguration {
    static func certificateVerificationDisabled(url: URL) -> Self? {
        guard url.scheme?.hasPrefix("mysql") == true else {
            return nil
        }
        guard let username = url.user else {
            return nil
        }
        guard let password = url.password else {
            return nil
        }
        guard let hostname = url.host else {
            return nil
        }
        let port = url.port ?? Self.ianaPortNumber

        let tlsConfiguration = TLSConfiguration.forClient(certificateVerification: .none)

        return self.init(
            hostname: hostname,
            port: port,
            username: username,
            password: password,
            database: url.path.split(separator: "/").last.flatMap(String.init),
            tlsConfiguration: tlsConfiguration
        )
    }
}
