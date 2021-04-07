# Rocket API

ツールのバージョンやインストール方法はDocument as a CodeとしてCIやバージョンファイルに記述されているのでそれを見てほしい。

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


## テスト

```bash
# テスト環境向けのシークレットを設定
$ cp ./Tests/.env.testing{.sample,}
$ docker-compose up db
$ swift test
# or Xcodeでテスト実行
```

## パッケージ分割戦略

メインのアプリケーション以外にいくつかExecutableなターゲットがあり、それらをビルドするときに不必要な依存をビルド/チェックアウトせずに済むようにパッケージを細かく切っている。

各パッケージの役割についてはそれぞれのパッケージのREADMEに書いてる。

## 注意

- usersテーブルの構造を変更する場合、cognito_usernameのマイグレータを最新の位置にズラすこと
