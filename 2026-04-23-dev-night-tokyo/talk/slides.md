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
    font-size: 40px;
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
  .columns-60-40 {
    display: grid;
    grid-template-columns: 3fr 2fr;
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
---

<!-- _class: lead -->

# oauth2-passkey

&nbsp;

### Passkey + OAuth2 認証ライブラリ for Rust / Axum

&nbsp;

### 高橋 公俊 (Kimitoshi Takahashi)

&nbsp;

<small>dev_night Tokyo #5 | 2026/04/23</small>

---

<!-- _class: lead -->

<div class="hook">

宣伝枠 📣

&nbsp;

Rust 修行のため
oauth2-passkey というライブラリを作ってます

&nbsp;

→ 今週 **Auth0 / Okta / Entra / Zitadel / Authentik**
使えるようにしました

</div>

<div class="hook-sub">

...今日動かしました

</div>

---

<!-- _class: lead -->

# Live Demo

### passkey-demo.ccmp.jp

---

## oauth2-passkeyとは

&nbsp;

<div class="columns-60-40">
<div>

1. **Auth0 / Okta** でログイン (= ユーザー作成)
2. **Passkey** を登録
3. 次回から Passkey だけでログイン

<div class="center-content">
&nbsp;

![w:220](../../shared/qr-demo.svg)

passkey-demo.ccmp.jp

</div>

</div>
<div>

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
</div>

---

## 3 行で組み込める

```rust
use oauth2_passkey_axum::{AuthUser, oauth2_passkey_full_router};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    oauth2_passkey_axum::init().await?;        // 1. 初期化

    let app = Router::new()
        .route("/", get(index))
        .merge(oauth2_passkey_full_router());  // 2. ルータ合流

    spawn_http_server(3001, app).await?;       // 3. サーバ起動
    Ok(())
}
```

- `/o2p/*` 配下に **ログイン UI / アカウント管理 / 管理画面** が全部生える
- ページ保護は `AuthUser` extractor または middleware で

---

## 対応 OAuth2 / OIDC プロバイダー

&nbsp;

<div class="providers">
<div>Google</div>
<div><strong>Auth0</strong></div>
<div><strong>Okta</strong></div>
<div>Keycloak</div>
<div>Microsoft Entra</div>
<div>Zitadel</div>
<div>Authentik</div>
<div>Custom (OIDC)</div>
</div>

&nbsp;

### .env を書き換えるだけ。コード変更なし

```env
OAUTH2_AUTH0_CLIENT_ID='xxx'
OAUTH2_AUTH0_CLIENT_SECRET='xxx'
OAUTH2_AUTH0_ISSUER_URL='https://your-tenant.auth0.com'
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
- 同一ユーザーの複数 IdP / 複数 Passkey の紐付けが DB で正規化される

---

## まとめ / Thank You!

<div class="with-qr">
<div>

### oauth2-passkey

- **Auth0 / Okta / Entra / Zitadel / Authentik** 対応（今週追加）
- 複数 IdP + 複数 Passkey を **account linking**
- Rust / Axum、crates.io 公開済み

&nbsp;

### 高橋 公俊

- フリーランス、Rust 3 年目
- 一緒にスタートアップしませんか

</div>
<div>

![w:150](../../shared/qr-github.svg) GitHub

![w:150](../../shared/qr-demo.svg) Demo

![w:150](../../shared/qr-contact.svg) Contact

</div>
</div>

---

<!-- _class: lead -->

# Backup Slides

---

## oauth2-passkey とは

&nbsp;

- **Rust / Axum** 向け Passkey + OAuth2 統合ライブラリ
- crates.io 公開済み: `oauth2-passkey`, `oauth2-passkey-axum`
- ライブデモ: **passkey-demo.ccmp.jp**

&nbsp;

### 特徴: 複数の IdP + 複数の Passkey を **同一ユーザー** に紐付け

```text
 👤 User (id: 1)
  │
  ├── 🌐 oauth2_accounts         ← Auth0 / Okta / Google / Keycloak ...
  │
  └── 🔑 passkey_credentials     ← Google Password / 1Password / YubiKey ...
```
