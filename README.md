# Rocket API

ツールのバージョンやインストール方法はDocument as a CodeとしてCIやバージョンファイルに記述されているのでそれを見てほしい。

## Environment

- Swift 5.2
- Xcode 12
- Vapor 4.5

<br>

## 実行

```bash
# 開発環境向けシークレット環境変数の設定
# 中身の値はキー名とマスクしてる値からだいたいわかるはず。
$ cp .env.development{.sample,}

$ swift run
# or
$ swift package generate-xcodeproj
$ open rocket-api.xcodeproj # Xcodeで実行
```

<br>

## テスト

```bash
# テスト環境向けのシークレットを設定
$ cp ./Tests/.env.testing{.sample,}
$ docker-compose up db
$ swift test
# or Xcodeでテスト実行
```

<br>

## Xcodeの設定

- Edit Schemes > Run > OptionsのUse custom working directoryにチェックし、rocket-apiのpathを記述
- Edit Schemes > Test > Infoの右下の方の「Options...」をクリックしExecute in Parallelにチェック
- Build Settingsの「Enable Testing Search Paths」をYesに

<br>

## パッケージ分割戦略

メインのアプリケーション以外にいくつかExecutableなターゲットがあり、それらをビルドするときに不必要な依存をビルド/チェックアウトせずに済むようにパッケージを細かく切っている。それぞれのパッケージのREADMEで詳細・サンプルを確認してください。

|||
|-|-|
|App|ルーター+コントローラー|
|AppTests|Appのテスト|
|DomainEntity|ドメインエンティティ|
|Endpoint|エンドポイントのスキーマ定義|
|Core|ドメインロジック|

処理の順番はApp->Core(Domain)->Core(Persistence)になっていて、DomainEntityとEndpointはどこからでも参照可能になっています。

