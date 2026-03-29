# Talking Points: oauth2-passkey

Tokyo Rust Show & Tell (2026/03/31) 15分発表用の話題整理。

## ライブラリの特徴（聴衆向け）

- Rust (Axum) で OAuth2/OIDC + Passkey/WebAuthn 認証を統合した唯一のライブラリ
- crates.io 公開済み（`oauth2-passkey`, `oauth2-passkey-axum`）
- SQLite / PostgreSQL / MySQL の3バックエンド対応（sqlx）
- `init()` + `merge(router)` + `AuthUser` の3行でAxumアプリに認証追加
- パスワードレス認証はホットトピック（Google/Apple/Microsoft対応）
- Cloud Run 上のライブデモあり

## Rust的な話題

### 1. LazyLock vs Axum State パターン
- Axum State はユーザーに `AppState` 構造体の管理を強いる
- LazyLock で DB 接続プールや設定を global に保持、state threading 不要
- 80+ の内部関数に state を渡す必要がなくなる
- `init().await?` で起動時に全 LazyLock を強制評価（fail-fast）
- トレードオフ: プロセスあたり1インスタンス、テスト時は `#[serial]` 必要
- **ファイル**: `oauth2_passkey/src/storage/data_store/config.rs`

### 2. DataStore trait によるマルチDB dispatch
- `trait DataStore: Send + Sync` に `as_sqlite()`, `as_postgres()`, `as_mysql()` を定義
- 各バックエンドが trait を実装（1つだけ `Some` を返す）
- `match (store.as_sqlite(), store.as_postgres(), store.as_mysql())` でディスパッチ
- ランタイムダウンキャスト不要、型安全
- **ファイル**: `oauth2_passkey/src/storage/data_store/types.rs`, `.../store_type.rs`

### 3. Newtype wrappers + コンストラクタ検証
- `UserId(String)`, `SessionId(String)`, `CsrfToken(String)`, `SessionCookie(String)` 等
- `CsrfHeaderVerified(pub bool)`, `AuthenticationStatus(pub bool)` — bool にも型をつける
- `new()` でバリデーション（空文字、長さ、不正文字、危険なシーケンス）
- 「UserId を持っていれば、それは必ず有効」— 再検証不要
- **ファイル**: `oauth2_passkey/src/session/types.rs`, `.../passkey/types.rs`

### 4. thiserror エラー階層 + From impl での自動ログ
- 各モジュール固有のエラー型: `OAuth2Error`, `PasskeyError`, `SessionError`, `UserError`
- `CoordinationError` が全モジュールエラーをラップ
- `From` impl 内で `tracing::error!()` を呼ぶ → `?` でモジュール境界を越えると自動ログ
- 手動の `tracing::error!()` を散在させる必要なし
- **ファイル**: `oauth2_passkey/src/coordination/errors.rs`

### 5. Axum AuthUser extractor（FromRequestParts 実装）
- `AuthUser` をハンドラ引数に書くだけで認証チェック + リダイレクト
- `Option<AuthUser>` で匿名アクセス許可
- FromRequestParts 内で CSRF 検証も自動実行（POST/PUT/DELETE/PATCH）
- ミドルウェア4種: `is_authenticated_{401,redirect}`, `is_authenticated_user_{401,redirect}`
- **ファイル**: `oauth2_passkey_axum/src/session.rs`, `.../middleware.rs`

### 6. subtle crate での constant-time 比較
- CSRF トークン検証に `ct_eq` を使用
- 通常の `==` はタイミング攻撃に脆弱（短い方が早く reject）
- `ct_eq` は一致位置に関係なく常に同じ時間
- **ファイル**: `oauth2_passkey_axum/src/session.rs` (line 201)

### 7. Atomic SQL（トランザクションなしでビジネスロジック）
- 「最後の admin でなければ削除」を1つの SQL 文で実現
- `DELETE ... WHERE id = $1 AND (SELECT COUNT(*) ... WHERE is_admin = true) > 1`
- 明示的トランザクション不要 = race condition なし
- **ファイル**: `oauth2_passkey/src/userdb/storage/postgres.rs`

### 8. SQL dialect 差異の吸収
- PostgreSQL: `RETURNING *` で INSERT 結果を1クエリで取得
- SQLite: RETURNING 非対応 → 2クエリ必要（INSERT + SELECT）
- MySQL: placeholder が `?`（PostgreSQL は `$1`）
- 3DB対応 = これらの quirks をバックエンドごとに実装
- **ファイル**: `oauth2_passkey/src/userdb/storage/{sqlite,postgres,mysql}.rs`

### 9. From/Into によるレイヤー間の型変換
- `DbUser` → `SessionUser` → `AuthUser` の3層
- 各レイヤーが独自の型を持ち、`From` impl で変換
- Axum 層で `csrf_token`, `session_id` 等のフレームワーク固有フィールドを追加
- **ファイル**: `oauth2_passkey/src/session/types.rs`, `oauth2_passkey_axum/src/session.rs`

### 10. Generic cache operations（trait bounds）
- `CacheErrorConversion<E>` trait で型安全なキャッシュ操作
- `get_data<T, E>` — `T: TryFrom<CacheData>`, `E: CacheErrorConversion<E>`
- モジュール横断で同じコードを再利用（セッション、チャレンジ、JWKS等）
- **ファイル**: `oauth2_passkey/src/storage/cache_operations.rs`

## 優先度の目安

| 優先度 | 話題 | 理由 |
|-------|------|------|
| **高** | LazyLock vs State | 設計判断として議論を呼びやすい |
| **高** | DataStore trait + マルチDB | Rust的に面白い、実用的 |
| **高** | AuthUser extractor | Axum ユーザーに直接役立つ |
| **中** | Newtype wrappers | Rust らしいパターン |
| **中** | thiserror + 自動ログ | 実践的なエラーハンドリング |
| **中** | Atomic SQL | DB設計の工夫 |
| **低** | subtle ct_eq | 短い話題、セキュリティに興味ある人向け |
| **低** | SQL dialect 差異 | sqlx ユーザー向けニッチ |
| **低** | From/Into レイヤー | 基本的すぎるかも |
| **低** | Generic cache ops | 内部実装寄り |


- passkey.demo.ccmp.jpでデモ

- モチベーションん
  - 提案のやつ
  - +DIY目的

- Oauth2でユーザー作成、Passkeyで認証
  - アカウントリンク
  - Google OAuth2/OIDC, FedCM
  - Passkey(Google PWM, Apple, MS, bitwarden, Proton Pass), Yubikey

- OAuth2/OIDCとPasskeyの説明

- ライブラリをどう使用するか
  - 初期化と、ルートのマウント
  - パスの保護Extractor
  - パスの保護middleware

- ストレージアクセス方法
  - sqlite, postgres, MySQL
  - in-memory, Redis

- LazyLock Pattern
  - ライブラリユーザーがStateを引き回すのが大変の解決

- アプリユーザーのデータベースとの連携
  - アカウントリンク/DBの内部構造
  - demo-profile, -todoでやってること

- まとめ、感謝、自己紹介
