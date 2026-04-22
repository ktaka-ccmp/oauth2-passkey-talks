---
marp: true
theme: default
paginate: true
size: 16:9
style: |
  section {
    font-size: 24px;
    display: flex !important;
    flex-flow: column nowrap !important;
    justify-content: flex-start !important;
    padding: 40px 60px 25px 60px !important;
  }
  section:not(.lead) > h2:first-of-type {
    margin-top: 0 !important;
    margin-bottom: 0.15em;
  }
  section.lead {
    justify-content: center !important;
    align-items: center !important;
    text-align: center;
    padding: 0 !important;
  }
  code {
    font-size: 19px;
  }
  pre {
    font-size: 18px;
    margin: 0.2em 0;
    padding: 0.4em;
    line-height: 1.4;
  }
  h1 {
    font-size: 48px;
    margin-bottom: 0.2em;
  }
  h2 {
    font-size: 32px;
    margin-top: 0;
    margin-bottom: 0.15em;
  }
  h3 {
    font-size: 24px;
    margin: 0.1em 0;
  }
  table {
    font-size: 21px;
  }
  ul, ol {
    margin: 0.1em 0;
  }
  li {
    margin: 0.05em 0;
    line-height: 1.4;
  }
  p {
    margin: 0.2em 0;
  }
  .columns-50-50 {
    display: grid;
    grid-template-columns: 3fr 3fr;
    gap: 0.8em;
    align-content: start;
  }
  .with-qr {
    display: grid;
    grid-template-columns: 3fr 2fr;
    gap: 2em;
    align-items: center;
    flex: 1;
  }
  .with-qr img {
    display: block;
  }
  section .with-qr > div:last-child {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    justify-content: center;
  }
  section .with-qr > div:last-child p {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
  .center-content p {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
  .providers {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 0.5em 1.2em;
    font-size: 26px;
    margin: 0.4em 0;
    text-align: center;
  }
  .providers > div {
    padding: 0.4em 0.6em;
    border: 1px solid #ccc;
    border-radius: 6px;
    background: #f7f7f7;
  }
  .hook {
    font-size: 44px;
    line-height: 1.5;
    text-align: center;
  }
  .hook-sub {
    font-size: 28px;
    text-align: center;
    margin-top: 1em;
    color: #666;
  }
  .video-row {
    display: flex;
    gap: 1em;
    justify-content: center;
    align-items: flex-start;
  }
  .video-row > div {
    text-align: center;
  }
  .video-row .caption {
    font-size: 20px;
    color: #555;
    margin-top: 0.3em;
  }
  .qr-video {
    display: flex;
    gap: 1.2em;
    justify-content: center;
    align-items: center;
  }
  .qr-video > div {
    text-align: center;
  }
  video.thumb {
    border: 2px solid #aaa;
    border-radius: 4px;
    cursor: pointer;
    display: block;
  }
---

<!-- _class: lead -->

# RustでOAuth2+Passkeyのライブラリを作ってます

&nbsp;

## 高橋 公俊 (Kimitoshi Takahashi)

&nbsp;

### dev_night Tokyo #5 | 2026/04/23

---

<!-- _class: lead -->

<div class="hook">

修行のためRustで
oauth2-passkey というライブラリを作ってます

&nbsp;

→ 今日のLTのために **Auth0 / Okta** 
使えるようにしました

</div>

<div class="hook-sub">

...今日動きました

</div>

---

## oauth2-passkeyとは

&nbsp;

<div class="columns-50-50">
<div>

OAuth2 / Passkey で認証 → Session Cookie 発行
crates.io 公開済み: `oauth2-passkey{,-axum}`
&nbsp;

```text
 👤 User
  │
  ├── 🌐 oauth2_accounts
  │   ├── (Auth0)
  │   ├── (Okta)
  │   └── (Google)
  │
  └── 🔑 passkey_credentials
      ├── (1Password)
      ├── (Google Password)
      └── (YubiKey)
```

複数のIdP/Passkey を一ユーザーに紐付け

</div>

<div>

1. **Auth0 / Okta** でユーザー作成
2. **Passkey** を登録
3. 次回から Passkey だけでログイン
&nbsp;

<div class="qr-video">

<div>

![w:180](../../shared/qr-demo.svg)
デモサイト
</div>

<div>
<a href="https://cdn.jsdelivr.net/gh/ktaka-ccmp/oauth2-passkey-talks@master/2026-03-31-tokyo-rust/video/oauth2-passkey-promotion.mp4" target="_blank" rel="noopener">
<video src="../../2026-03-31-tokyo-rust/video/oauth2-passkey-promotion.mp4" width="120" muted controls class="thumb"></video>
</a>

デモ動画
</div>

<div>
<a href="https://cdn.jsdelivr.net/gh/ktaka-ccmp/oauth2-passkey-talks@master/2026-03-31-tokyo-rust/video/oauth2-passkey-promotion.mp4" target="_blank" rel="noopener">
<video src="../../2026-03-31-tokyo-rust/video/oauth2-passkey-promotion.mp4" width="120" muted controls class="thumb"></video>
</a>

デモ動画
</div>

</div>

</div>
</div>

---

## 3 行で組み込める

&nbsp;

```rust
use oauth2_passkey_axum::{AuthUser, oauth2_passkey_full_router}; // 1. インポート

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    oauth2_passkey_axum::init().await?;                // 2. 初期化

    let app = Router::new()
        .route("/", get(index))
        .merge(oauth2_passkey_full_router());          // 3. ルータ合流

    spawn_http_server(3001, app).await?;
    Ok(())
}
```

- OAuth2(OIDC)/Passkey のエンドポイント、ログインUI、管理画面 が自動作成される
- ページ保護は `AuthUser` extractor または middleware で

---

## 対応 OAuth2 / OIDC プロバイダー

&nbsp;

<div class="providers">
<div><strong>Auth0</strong></div>
<div><strong>Okta</strong></div>
<div>Google</div>
<div>Microsoft Entra</div>
<div>Keycloak</div>
<div>Zitadel</div>
<div>Authentik</div>
<div>Custom (OIDC)</div>
</div>

&nbsp;

### .env を書き換えるだけ。コード変更なし

```env
OAUTH2_CUSTOM1_NAME='auth0'
OAUTH2_CUSTOM1_CLIENT_ID='xxx'
OAUTH2_CUSTOM1_CLIENT_SECRET='xxx'
OAUTH2_CUSTOM1_ISSUER_URL='https://your-tenant.auth0.com'
```

---

## ストレージも .env で切り替え

&nbsp;

```env
# SQLite (開発・デモ用、セットアップ不要)
GENERIC_DATA_STORE_TYPE=sqlite
GENERIC_DATA_STORE_URL='sqlite:/tmp/auth.db'

# PostgreSQL / MySQL / MariaDB
GENERIC_DATA_STORE_TYPE=postgres        # or mysql
GENERIC_DATA_STORE_URL='postgres://user:pass@localhost/mydb'

# Cache: in-memory または Redis
GENERIC_CACHE_STORE_TYPE=memory         # or redis
```

- コード変更不要

---

## まとめ / Thank You!

<div class="with-qr">
<div>

### oauth2-passkey

- Rust / Axum 向け認証ライブラリ
- crates.io 公開済み
- 複数 IdP + 複数 Passkey を **account linking**
- **Auth0 / Okta** などのOIDC IDP 対応

&nbsp;

### 高橋 公俊

- フリーランス
- Rust 3 年目
- 一緒にスタートアップしませんか

</div>

<div>

![w:200](../../shared/qr-github.svg) GitHub

<!-- ![w:150](../../shared/qr-demo.svg) Demo -->

![w:200](../../shared/qr-contact.svg) Contact

</div>
</div>
