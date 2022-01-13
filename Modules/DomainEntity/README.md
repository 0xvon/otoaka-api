# DomainEntity

サービスのドメインにおけるエンティティを定義するモジュール。クライアントアプリと共有して使っている。

例

```swift
public struct User: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var name: String
    public var username: String?
    public var biography: String?
    public var sex: String?
    public var age: Int?
    public var liveStyle: String?
    public var residence: String?
    public var thumbnailURL: String?
    public var role: RoleProperties
    public var twitterUrl: URL?
    public var instagramUrl: URL?
    public var point: Int
    ...
}
```