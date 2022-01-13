# Endpoint

APIエンドポイントの入出力を定義するモジュールです。
クライアントアプリと共有して使っているため、VaporやSwiftNIOなどServer Side Swift向けのライブラリ依存が入らないようにしています。

当初はSwiftの型を生かしたRPCとして使う予定だったが、中途半端にRESTを意識したURL設計にしてしまい、クライアント側の使い心地が微妙になってしまった。

例

```swift
public struct SignupStatus: EndpointProtocol {
    public typealias Request = Empty // Requestの型
    public struct Response: Codable { // Responseの型
        public var isSignedup: Bool
        public init(isSignedup: Bool) {
            self.isSignedup = isSignedup
        }
    }
    public struct URI: CodableURL { // スキーマ
        @StaticPath("users", "get_signup_status") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .get // HTTPメソッド
}
```