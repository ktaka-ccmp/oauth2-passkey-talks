# Tokyo Rust Show & Tell -- oauth2-passkey 発表準備

## イベント情報

| 項目 | 詳細 |
|------|------|
| イベント名 | Tokyo Rust Show & Tell - Volunteers Welcome! |
| 日時 | 2026/03/31 (火) 18:30 - 21:00 JST |
| 場所 | 祐天寺駅近くの公共施設（目黒区上目黒 B101室） |
| 形式 | Show & Tell（プロジェクト発表・デモ）、対面 |
| 費用 | 無料 |
| 言語 | 英語・日本語どちらもOK |
| URL | https://guild.host/events/tokyo-rust-show-tell-kwpu3m |

## プロジェクト概要

- **リポジトリ**: ~/GitHub/oauth2-passkey
- **crates.io**: oauth2-passkey, oauth2-passkey-axum
- **ライブデモ**: Cloud Run 上で稼働中
- **概要**: Rust + Axum で OAuth2 (Google) と WebAuthn/Passkey 認証を提供するライブラリ

### 主な特徴

- パスワードレス認証（Passkey）+ OAuth2 統合
- SQLite / PostgreSQL / MySQL の 3 バックエンド対応（sqlx）
- レイヤード設計（core library ↔ Axum integration）
- crates.io 公開済みライブラリ
- FedCM（実験的機能）

## 発表構成案（15分）

1. **ライブデモ**（4分）
   - Passkey 登録→ログイン
   - Google OAuth2 ログイン
   - アカウントリンク（OAuth2 + Passkey を同一ユーザーに紐付け）

2. **モチベーション**（2分）
   - なぜパスワードレス認証ライブラリを作ったか

3. **OAuth2 / WebAuthn/Passkey とは**（2分）
   - OAuth2 の基本フロー
   - 公開鍵暗号ベースの認証、フィッシング耐性

4. **アーキテクチャ & Rust 的な話**（5分）
   - レイヤード設計（core library ↔ Axum integration）
   - sqlx でのマルチ DB 対応（SQLite/PostgreSQL/MySQL）
   - Transaction パターンなど実装の工夫
   - crates.io 公開ライブラリとしての設計判断（thiserror、最小 visibility）

5. **まとめ & 今後 & 自己紹介**（2分）
   - DPoP、Bearer Token 対応の展望
   - crates.io リンク
   - 自己紹介、連絡先
 - 

## 発表構成案（5分）

1. **oauth2-passkey の概要**（1分）
   - パスワードレス認証ライブラリ、Rust + Axum、crates.io 公開済み
2. **ライブデモ**（2.5分）
   - Passkey 登録→ログイン、Google OAuth2 ログイン
3. **Rust 的なポイント**（1分）
   - sqlx マルチ DB、レイヤード設計
4. **まとめ**（0.5分）

## 聴衆にとって刺さりそうなポイント

- Rust + Axum で WebAuthn/Passkey 認証を実装（Rust での実用的な Web アプリ事例）
- パスワードレス認証はホットトピック
- OAuth2 + Passkey の統合ライブラリは珍しい
- SQLite/PostgreSQL/MySQL の 3 バックエンド対応（sqlx の実践的な使い方）
- crates.io に公開済み

## デモで見せられるもの

- Passkey の登録・ログインフロー（指紋/顔認証）
- OAuth2 (Google) ログインと Passkey の連携
- FedCM のブラウザネイティブ UI（実験的機能）
- Cloud Run 上のライブデモサイト

## スライドツール

Marp（Markdown → スライド）を使用予定。
