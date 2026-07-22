# PowerShellによる実装テスト

PowerShellによるパスワード管理アプリケーションのテストです。PowerShellのGUI(WPF(XAML))による実装テストを行っているリポジトリです。 

---

# SimplePASS - PowerShell パスワード管理ツール

Windows環境で動作する、ローカル完結型かつ高セキュリティなパスワード管理GUIアプリケーションです。

---

## 🌟 特長

* **グラフィカルな操作画面**: PowerShell + WPF (XAML) で構築されたモダンでシンプルな操作画面。
* **Enterキーログイン対応**: パスワード入力後、Enterキー押下で素早く解読・ログインが可能。
* **強力な二重暗号化**: Windows DPAPI と AES-256-CBC + PBKDF2 による高いセキュリティ保護。
* **フォルダ単位のポータブル管理**: アプリ直下の `data\vault.json` に保存され、フォルダごと移動・持ち運びが可能。
* **クリップボード自動保護**: パスワードコピー後、30秒経過でクリップボードを自動クリア。
* **パスワード自動生成**: 英大・小文字、数字、記号を網羅したランダムパスワード生成機能。
* **リアルタイム検索**: 登録したサービス名、URL、ユーザー名、メモからの即時絞り込み。
* **統合エラーログ管理**: 未捕捉例外発生時、`data\logs\app.log` へスタックトレースを安全に追記・保存（1MB自動ローテーション）。

---

## 🛡️ セキュリティ仕様 & フォルダ管理

本ツールは外部サーバー通信を一切行わず、データはアプリケーション直下の **`data\vault.json` (フォルダ単位管理)** に暗号化保存されます。
アプリが入ったフォルダーごと移動・保管（ポータブル管理）が可能です。

1. **Windows DPAPI (`CurrentUser` スコープ)**
   * 現在ログオンしているWindowsユーザーアカウント固有の鍵で保護されます。ファイルを別アカウントや別PCへコピー取出しされても解読できません。
2. **AES-256-CBC + PBKDF2 (100,000イテレーション)**
   * マスターパスワードから個別のランダムSaltを用いて鍵を導出し、データを暗号化します。正しいマスターパスワードを知らない限り、PC管理者権限であっても総当たり解読は不可能です。
3. **メモリセッション管理**
   * マスターパスワードや復号鍵はメモリ上に永続化せず、アプリ終了時または「Lock Vault」ボタン押下時に破棄されます。
4. **統合エラーログ管理 (LoggerModule)**
   * 万が一の例外発生時、画面を破綻させずに `data\logs\app.log` へタイムスタンプ付きの例外詳細およびスタックトレースを自動記録・管理します。（1MBでの自動ローテーション機能付き）

---

## 💻 動作環境

* **OS**: Windows 10 / Windows 11
* **Shell**: PowerShell 5.1 以上 (Windows標準PowerShell対応)

---

## 🚀 起動方法

リポジトリ直下にあるバッチファイルをダブルクリック（またはコマンドラインから実行）するだけで起動できます。

* **日本語版で起動する場合**:
  * **`start_JP.bat`** または **`SimplePASS_JP.bat`** をダブルクリック
* **英語版で起動する場合**:
  * **`start.bat`** または **`SimplePASS.bat`** をダブルクリック

```cmd
# 日本語版を起動する場合
start_JP.bat

# 英語版を起動する場合
start.bat
```

---

## 📁 ディレクトリ構成

```text
SimplePASS/
├── start.bat                         # 起動用バッチファイル (相対パス起動)
├── SimplePASS.bat                    # 起動用バッチファイル
├── README.md                         # 本ドキュメント
├── plan.md                           # 計画・設計仕様書
├── data/
│   ├── vault.json                    # 暗号化保管庫ファイル (フォルダ単位管理)
│   └── logs/
│       └── app.log                   # 統合エラーログファイル (1MB自動ローテーション)
├── src/
│   ├── SimplePASS.ps1                # メイン GUI アプリケーション (WPF)
│   ├── CryptoModule.psm1             # 暗号化・復号モジュール (AES-256 + PBKDF2 + DPAPI)
│   ├── VaultModule.psm1              # 保管庫データ CRUD・永続化モジュール
│   ├── UtilsModule.psm1              # パスワード生成・クリップボード制御モジュール
│   └── LoggerModule.psm1             # 統合ログ記録・未捕捉例外ハンドラーモジュール
└── tests/
    ├── RunAllTests.ps1               # 全自動テストスイートランナー (全21項目)
    ├── Crypto.Tests.ps1              # 暗号強度・解読不能・改ざん検知テスト
    ├── Vault.Tests.ps1               # CRUD・インジェクション耐性・フォルダパス生成テスト
    ├── Utils.Tests.ps1               # パスワード生成境界値・クリップボード動作テスト
    ├── GUI.Tests.ps1                 # DataGrid ItemsSource バインディング・XAMLパーステスト
    ├── GUI_FullButtons.Tests.ps1     # 全11種ボタン操作・全GUI機能網羅テスト
    ├── GUI_CriticalUserOperations.Tests.ps1 # 批判的ユーザー操作・検索復帰・再認証テスト
    └── Logger.Tests.ps1              # ログ出力・スタックトレース記録テスト
```

---

## 🧪 テストの実行方法

全21項目の全自動統合テストスイートが含まれています。

```powershell
powershell -ExecutionPolicy Bypass -File "tests\RunAllTests.ps1"
```
