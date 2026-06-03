#!/bin/bash
# 安全停止 OpenClaw 和 Docker 容器
# 確保所有數據和配置都已保存

set -e

echo "🛑 安全停止 OpenClaw..."
echo ""

# 1. 檢查容器狀態
echo "1️⃣  檢查容器狀態..."
if ! docker compose ps | grep -q "openclaw-gateway.*Up"; then
  echo "   ℹ️  OpenClaw Gateway 容器未運行"
else
  echo "   ✅ OpenClaw Gateway 正在運行"
fi
echo ""

# 2. 停止容器（優雅停止）
echo "2️⃣  優雅停止容器..."
echo "   發送 SIGTERM 信號，允許服務正常關閉..."
docker compose stop openclaw-gateway 2>&1 | grep -v "level=warning" || true
sleep 2

# 檢查是否還有運行中的容器
if docker compose ps | grep -q "openclaw-gateway.*Up"; then
  echo "   ⚠️  容器仍在運行，等待 5 秒後強制停止..."
  sleep 5
  docker compose kill openclaw-gateway 2>&1 | grep -v "level=warning" || true
fi
echo ""

# 3. 驗證數據目錄
echo "3️⃣  驗證數據持久化..."
CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"

if [ -d "${CONFIG_DIR}" ]; then
  CONFIG_SIZE=$(du -sh "${CONFIG_DIR}" 2>/dev/null | cut -f1)
  echo "   ✅ 配置目錄：${CONFIG_DIR} (${CONFIG_SIZE})"
  
  # 檢查關鍵文件
  if [ -f "${CONFIG_DIR}/openclaw.json" ]; then
    echo "      - openclaw.json ✓"
  fi
  
  if [ -d "${CONFIG_DIR}/agents" ]; then
    SESSION_COUNT=$(find "${CONFIG_DIR}/agents" -name "sessions.json" 2>/dev/null | wc -l | tr -d ' ')
    echo "      - agents/ (${SESSION_COUNT} 個 agent) ✓"
  fi
else
  echo "   ⚠️  配置目錄不存在：${CONFIG_DIR}"
fi

if [ -d "${WORKSPACE_DIR}" ]; then
  WORKSPACE_SIZE=$(du -sh "${WORKSPACE_DIR}" 2>/dev/null | cut -f1)
  echo "   ✅ 工作區目錄：${WORKSPACE_DIR} (${WORKSPACE_SIZE})"
  
  # 檢查關鍵文件
  [ -f "${WORKSPACE_DIR}/AGENTS.md" ] && echo "      - AGENTS.md ✓"
  [ -f "${WORKSPACE_DIR}/SOUL.md" ] && echo "      - SOUL.md ✓"
  [ -f "${WORKSPACE_DIR}/MEMORY.md" ] && echo "      - MEMORY.md ✓"
  [ -d "${WORKSPACE_DIR}/memory" ] && echo "      - memory/ ✓"
  [ -d "${WORKSPACE_DIR}/skills" ] && echo "      - skills/ ✓"
else
  echo "   ⚠️  工作區目錄不存在：${WORKSPACE_DIR}"
fi
echo ""

# 4. 確認容器已停止
echo "4️⃣  確認容器狀態..."
if docker compose ps | grep -q "openclaw-gateway.*Up"; then
  echo "   ⚠️  警告：容器仍在運行"
  echo "   運行 'docker compose down' 以完全停止所有容器"
else
  echo "   ✅ 所有容器已停止"
fi
echo ""

echo "✅ 停止完成！"
echo ""
echo "📝 數據保存位置："
echo "   - 配置和會話：${CONFIG_DIR}"
echo "   - 工作區和記憶：${WORKSPACE_DIR}"
echo ""
echo "🔄 重新啟動："
echo "   docker compose up -d openclaw-gateway"
echo ""
echo "🗑️  完全移除容器（保留數據）："
echo "   docker compose down"
