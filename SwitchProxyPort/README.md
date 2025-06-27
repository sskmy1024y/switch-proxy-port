# SwitchProxyPort

macOSステータスバー常駐型のプロキシサーバー切り替えアプリケーション

## 機能

- **プロキシサーバー**: 指定ポート（デフォルト8080）でHTTP/TCPプロキシサーバーとして動作
- **動的ポート切り替え**: 複数の転送先ポート間で動的に切り替え可能
- **ステータスバー操作**: ステータスバーアイコンから簡単に操作
- **設定永続化**: アプリケーション設定を自動保存・復元

## 使用方法

### 1. 起動方法

#### Option A: アプリバンドル（推奨）
```bash
# アプリを作成
./build-app.sh

# アプリを起動
open SwitchProxyPort.app
```

#### Option B: 開発モード
```bash
cd SwitchProxyPortSPM
./run.sh
```

#### Option C: DMG配布
```bash
# DMGファイルを作成
./create-dmg.sh

# DMGを開いてアプリをApplicationsにドラッグ
open SwitchProxyPort-1.0.0.dmg
```

### 2. 基本操作
1. 右上のステータスバーにアイコンが表示されます
2. アイコンをクリックしてメニューを開きます
3. "Turn On" でプロキシサーバーを開始
4. "Target Ports" から転送先ポートを選択
5. "Preferences..." から詳細設定が可能

### 3. デフォルト設定
- **受付ポート**: 8080
- **転送先ポート**: 3000, 3001, 3002
- **初期状態**: オフ

### 4. 詳細設定（Preferences）
設定画面では以下の項目を変更できます：
- **Listen Port**: プロキシサーバーの受付ポート番号
- **Target Ports**: 転送先ポート一覧の追加・削除
- **Auto Start**: ログイン時の自動起動（未実装）

### 5. プロキシ設定例
ブラウザのプロキシ設定で以下を指定：
- HTTPプロキシ: `127.0.0.1:8080`
- HTTPSプロキシ: `127.0.0.1:8080`

## 開発

### 開発環境ビルド
```bash
swift build
```

### リリース用アプリ作成
```bash
./build-app.sh
```

### DMG配布パッケージ作成
```bash
./create-dmg.sh
```

### デバッグ
```bash
# 開発モードで実行
./run.sh

# 直接実行
.build/debug/SwitchProxyPort
```

## 配布

詳細な配布手順は `DISTRIBUTION.md` を参照してください。

- **アプリバンドル**: `SwitchProxyPort.app`
- **DMGファイル**: `SwitchProxyPort-1.0.0.dmg`
- **配布用スクリプト**: `build-app.sh`, `create-dmg.sh`

## システム要件

- macOS 12.0 以上
- Swift 5.7 以上

## ライセンス

このソフトウェアはMITライセンスの下で配布されています。