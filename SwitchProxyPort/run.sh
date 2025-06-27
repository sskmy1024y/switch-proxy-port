#!/bin/bash
cd "$(dirname "$0")"
swift build
if [ $? -eq 0 ]; then
    echo "アプリケーションを起動しています..."
    echo "プロキシサーバーの切り替えは右上のステータスバーアイコンから操作できます"
    echo "終了するには Ctrl+C を押してください"
    .build/debug/SwitchProxyPort
else
    echo "ビルドに失敗しました"
fi