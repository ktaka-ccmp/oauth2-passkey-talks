# Talking Points: oauth2-passkey

Tokyo Rust Show & Tell (2026/03/31) 15分発表用。

## 発表の流れ

### 1. デモ (4分)
- passkey-demo.ccmp.jp でライブデモ
- **ストーリー**: 初めてのユーザーとして体験させる
  1. Google OAuth2 で初回ログイン
  2. Passkey Promotion → 指紋/顔を登録
  3. ログアウト → Passkey だけで再ログイン（リダイレクトなし、一瞬）
  4. アカウント管理画面で OAuth2 + Passkey の紐付けを確認
- 対応 authenticator: Google Password Manager, Apple, Windows Hello, bitwarden, Proton Pass, YubiKey
- FedCM も見せられたら見せる（ブラウザネイティブUI）
- **失敗時**: スクリーンショット or ブログ記事のデモ動画を見せる

### 2. モチベーション (30秒)
- 「今見たものを自分で作りたかった。Rust で。」
- 既存エコシステム: webauthn-rs (WebAuthn only), OAuth2 crates (OAuth2 only)
- **統合ソリューション + セッション管理** が無かった → 作った → crates.io 公開済み

### 3. アジェンダ (15秒)
- 残りの時間でこれを話します、と見せるだけ

### 4. OAuth2 / Passkey の仕組み (2分)
- **OAuth2/OIDC**: ページリダイレクト型。Google にリダイレクト → authorization code → id_token (JWT) → セッション
- **Passkey/WebAuthn**: JavaScript 制御。サーバがチャレンジ発行 → Authenticator が秘密鍵で署名 → サーバが公開鍵で検証
- Mermaid シーケンス図で説明
- 対比ポイント: OAuth2 は外部サービス依存、Passkey は自前完結

### 5. ライブラリの使い方 (3分)
- **init + merge**: 3行で認証追加
- **Built-in UI**: ログインページ、アカウント管理、管理パネルが組み込み（ユーザーが作る必要なし）
- **AuthUser extractor**: ハンドラ引数に書くだけで認証チェック
  - `AuthUser` → 未認証ならリダイレクト
  - `Option<AuthUser>` → 匿名アクセス許可
- **Middleware 4種**: 401/redirect × with/without AuthUser
- ここは Axum ユーザーに直接役立つ話

### 6. ストレージ & LazyLock (3分)
- **DataStore trait**: SQLite/PostgreSQL/MySQL を1つの trait で抽象化
  - `as_sqlite()` / `as_postgres()` / `as_mysql()` → match でディスパッチ
  - ランタイムダウンキャスト不要
- **LazyLock vs Axum State**: なぜ State パターンを使わないか
  - ライブラリ内部に 80+ の関数 → 全部に State を渡すのは非現実的
  - LazyLock で global に保持 → ユーザーは `AppState` を作る必要なし
  - `init().await?` で起動時に強制評価（fail-fast）
  - トレードオフ: プロセスあたり1インスタンス、テスト時は `#[serial]`
- **ここが一番議論を呼びやすい** — 「State 使うべきでは？」への回答を用意

### 7. アプリ DB との連携 (2分)
- oauth2-passkey が管理: users, oauth2_accounts, passkey_credentials, sessions
- アプリは `AuthUser.id` を FK にして自分のテーブルを持つ
- **demo-profile** (1:1): ユーザープロフィール拡張、Google avatar 自動取得
- **demo-todo** (1:N): TODO リスト、ユーザー隔離
- DB は別でも同じでも OK

### 8. まとめ・自己紹介 (30秒)
- Summary テーブル + QR
- Thank you + Questions

## ライブラリの差別化ポイント

- Rust (Axum) で OAuth2 + Passkey を**統合**した唯一のライブラリ
- **Passkey Promotion**: OAuth2 ログイン後に Passkey 登録を自動的に促す
- **Built-in UI**: ログイン、アカウント管理、管理パネル組み込み
- **3 DB 対応**: SQLite / PostgreSQL / MySQL (sqlx)
- **Login History**: デバイス・認証器の記録
- **テーマ**: 9 built-in + カスタム CSS
- crates.io 公開済み、ドキュメントサイトあり

## Rust 的な話題（メインスライドに入れたもの）

| 話題 | スライド | 議論を呼ぶ度 |
|------|---------|-----------|
| LazyLock vs Axum State | p15-16 | 高 — 設計判断の是非 |
| DataStore trait + マルチDB dispatch | p14 | 高 — Rust的で実用的 |
| AuthUser extractor (FromRequestParts) | p11 | 中 — Axumユーザーに役立つ |
| Middleware 4種 | p12 | 中 |

## Rust 的な話題（Extra Slides / 質疑用）

| 話題 | 一言 |
|------|------|
| Newtype wrappers | UserId, CsrfToken 等で型安全、コンストラクタで検証 |
| thiserror エラー階層 | モジュール別エラー + From impl で自動ログ |
| subtle ct_eq | CSRF トークンの constant-time 比較 |
| Atomic SQL | トランザクションなしで「最後の admin でなければ削除」 |
| SQL dialect 差異 | PostgreSQL RETURNING vs SQLite 2クエリ |
| From/Into レイヤー | DbUser → SessionUser → AuthUser |

## 想定質問

- **「なぜ State を使わないの？」** → ライブラリとして使いやすさ優先。80+ 関数に State 渡すのは非現実的。
- **「セキュリティ監査は？」** → subtle crate で constant-time 比較、CSRF 自動検証、セッション cookie は `__Host-` prefix
- **「他のフレームワーク対応は？」** → core crate はフレームワーク非依存。Axum 以外の integration crate を作れば対応可能。
- **「テストどうしてる？」** → `#[serial]` + 各 DB バックエンドでの統合テスト
- **「FedCM って何？」** → ブラウザネイティブの ID 選択 UI。experimental。
