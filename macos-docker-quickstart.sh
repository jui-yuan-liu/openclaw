#!/usr/bin/env bash
# macOS Docker 快速設置腳本（支援沙箱）
# 這個腳本會自動完成所有必要的設置步驟

set -euo pipefail

echo "🦞 OpenClaw macOS Docker 快速設置（支援沙箱模式）"
echo "=================================================="
echo ""

# 檢查 Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ 錯誤：未找到 Docker"
  echo "請先安裝 Docker Desktop: https://www.docker.com/products/docker-desktop"
  exit 1
fi

if ! docker ps >/dev/null 2>&1; then
  echo "❌ 錯誤：Docker 未運行"
  echo "請啟動 Docker Desktop 並重試"
  exit 1
fi

echo "✅ Docker 已就緒"
echo ""

# 檢查 Docker Compose
if ! docker compose version >/dev/null 2>&1; then
  echo "❌ 錯誤：Docker Compose 不可用"
  exit 1
fi

echo "✅ Docker Compose 已就緒"
echo ""

# 設定目錄
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"

echo "📁 建立配置目錄..."
mkdir -p "$OPENCLAW_CONFIG_DIR"
mkdir -p "$OPENCLAW_WORKSPACE_DIR"
echo "✅ 配置目錄已建立：$OPENCLAW_CONFIG_DIR"
echo ""

# 建立 .env 檔案（如果不存在）
if [[ ! -f .env ]]; then
  echo "📝 建立 .env 檔案..."
  cat > .env << EOF
# OpenClaw Docker 設定
OPENCLAW_CONFIG_DIR=$OPENCLAW_CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$OPENCLAW_WORKSPACE_DIR
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_IMAGE=openclaw:local
EOF

  # 生成 Gateway Token
  if command -v openssl >/dev/null 2>&1; then
    OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32)"
  else
    OPENCLAW_GATEWAY_TOKEN="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
  fi
  echo "OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN" >> .env
  
  # 加入 Ollama 配置（如果 Ollama 運行在本地）
  echo "" >> .env
  echo "# Ollama 配置（本地模型）" >> .env
  echo "OLLAMA_API_KEY=ollama-local" >> .env
  echo "OLLAMA_BASE_URL=http://host.docker.internal:11434" >> .env
  
  echo "✅ .env 檔案已建立（包含 Ollama 配置）"
else
  echo "ℹ️  .env 檔案已存在，跳過建立"
fi
echo ""

# 建立 Gateway Image
echo "🔨 建立 OpenClaw Gateway Image..."
echo "這可能需要 5-15 分鐘，請耐心等待..."
if docker build -t openclaw:local -f Dockerfile .; then
  echo "✅ Gateway Image 建立完成"
else
  echo "❌ Gateway Image 建立失敗"
  exit 1
fi
echo ""

# 建立沙箱 Image
echo "🔨 建立沙箱 Image..."
if [[ -f scripts/sandbox-setup.sh ]]; then
  if ./scripts/sandbox-setup.sh; then
    echo "✅ 沙箱 Image 建立完成"
  else
    echo "⚠️  警告：沙箱 Image 建立失敗，但可以繼續"
  fi
else
  echo "⚠️  警告：找不到 sandbox-setup.sh，跳過沙箱 Image 建立"
fi
echo ""

# 顯示下一步指示
echo "🎉 設置完成！"
echo ""
echo "下一步："
echo ""
echo "1. 啟動 Gateway："
echo "   docker compose up -d openclaw-gateway"
echo ""
echo "2. 執行 Onboarding Wizard："
echo "   docker compose run --rm openclaw-cli onboard"
echo ""
echo "3. 設定沙箱模式（編輯 ~/.openclaw/openclaw.json）："
echo "   參考 MACOS_DOCKER_SETUP.md 中的步驟 5"
echo ""
echo "4. 存取 Control UI："
echo "   http://127.0.0.1:18789/"
echo ""
echo "5. 配置 Ollama（如果使用本地模型）："
echo "   參考 OLLAMA_SETUP.md"
echo ""
echo "6. 查看完整指南："
echo "   cat MACOS_DOCKER_SETUP.md"
echo ""
