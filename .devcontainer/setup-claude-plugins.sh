#!/bin/bash
#
# Claude Code のインストールとプラグイン設定
#

set -euo pipefail

MARKETPLACE_URL="https://github.com/kiririmode/claude-plugins"
MARKETPLACE_NAME="kiririmode-claudecode-plugins"

PLUGINS=(
    "common-dev-essentials"
    "general"
    "github-dev-essentials"
)

# Claude Code のインストール
if ! command -v claude &> /dev/null; then
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
fi

# マーケットプレイスの追加（未インストールの場合のみ）
if claude plugin marketplace list 2>/dev/null | grep -q "${MARKETPLACE_NAME}"; then
    echo "Marketplace '${MARKETPLACE_NAME}' is already installed, skipping..."
else
    echo "Adding marketplace: ${MARKETPLACE_URL}"
    claude plugin marketplace add "${MARKETPLACE_URL}"
fi

# プラグインのインストール
for plugin in "${PLUGINS[@]}"; do
    echo "Installing plugin: ${plugin}@${MARKETPLACE_NAME}"
    claude plugin install "${plugin}@${MARKETPLACE_NAME}"
done

echo "Claude Code setup complete!"
