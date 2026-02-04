# macOS Docker 安裝 OpenClaw 完整指南（支援沙箱模式）

本指南將逐步教您如何在 macOS 上使用 Docker 安裝和運行 OpenClaw，並啟用沙箱安全模式。

## 📋 前置需求

1. **macOS**（任何現代版本）
2. **Docker Desktop for Mac**（已安裝並運行）
   - 下載：https://www.docker.com/products/docker-desktop
   - 確認運行：打開 Docker Desktop，確認狀態為 "Running"
3. **Git**（用於克隆倉庫）
4. **終端機**（Terminal.app 或 iTerm2）

## 🚀 步驟 1：準備環境

### 1.1 確認 Docker 運行

打開終端機，執行：

```bash
docker --version
docker compose version
docker ps
```

如果都能正常執行，表示 Docker 已準備就緒。

### 1.2 克隆或進入 OpenClaw 專案目錄

```bash
# 如果您還沒有專案，先克隆
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 或者如果您已經有專案，直接進入目錄
cd /path/to/openclaw
```

## 🔧 步驟 2：建立 Docker Image

### 2.1 建立 OpenClaw Gateway Image

```bash
# 建立主要的 Gateway image
docker build -t openclaw:local -f Dockerfile .
```

這會需要一些時間（5-15 分鐘），因為需要：
- 安裝依賴套件
- 編譯 TypeScript
- 建置 UI

### 2.2 建立沙箱 Image（重要！）

沙箱功能需要額外的 Docker image：

```bash
# 建立基礎沙箱 image
./scripts/sandbox-setup.sh

# 這會建立：openclaw-sandbox:bookworm-slim
```

**可選：建立沙箱瀏覽器 image**（如果需要瀏覽器工具在沙箱中運行）

```bash
# 建立沙箱瀏覽器 image
./scripts/sandbox-browser-setup.sh
```

## 📝 步驟 3：設定環境變數

### 3.1 建立 `.env` 檔案

在專案根目錄建立 `.env` 檔案：

```bash
cat > .env << 'EOF'
# OpenClaw Docker 設定

# 配置目錄（macOS 上的路徑）
OPENCLAW_CONFIG_DIR=$HOME/.openclaw
OPENCLAW_WORKSPACE_DIR=$HOME/.openclaw/workspace

# Gateway 設定
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=lan

# Image 名稱
OPENCLAW_IMAGE=openclaw:local

# Gateway Token（自動生成，或手動設定）
# OPENCLAW_GATEWAY_TOKEN=your-token-here

# Ollama 配置（本地模型）
# macOS Docker Desktop 使用 host.docker.internal 訪問主機服務
OLLAMA_API_KEY=ollama-local
OLLAMA_BASE_URL=http://host.docker.internal:11434

# 模型認證（根據您使用的模型設定）
# CLAUDE_AI_SESSION_KEY=your-key
# CLAUDE_WEB_SESSION_KEY=your-key
# CLAUDE_WEB_COOKIE=your-cookie
EOF
```

### 3.2 建立配置目錄

```bash
mkdir -p ~/.openclaw
mkdir -p ~/.openclaw/workspace
```

## 🐳 步驟 4：啟動 OpenClaw（使用支援沙箱的設定）

### 4.1 使用支援沙箱的 docker-compose

我們有兩個選擇：

**選項 A：使用官方腳本（會自動處理）**

```bash
# 官方腳本會自動處理大部分設定
./docker-setup.sh
```

**選項 B：手動啟動（推薦）**

```bash
# 直接使用 docker-compose.yml（已包含沙箱支援）
docker compose up -d openclaw-gateway
```

**注意：** `docker-compose.yml` 已經包含 Docker socket 掛載和 `--allow-unconfigured` 參數，無需額外的 sandbox 檔案。

### 4.2 確認容器運行

```bash
# 查看容器狀態
docker compose ps

# 查看 Gateway 日誌
docker compose logs -f openclaw-gateway
```

您應該看到類似這樣的輸出：

```
openclaw-gateway-1  | Gateway listening on ws://0.0.0.0:18789
openclaw-gateway-1  | Control UI available at http://127.0.0.1:18789/
```

## ⚙️ 步驟 5：設定沙箱模式

### 5.1 執行 Onboarding Wizard

```bash
# 使用 CLI 容器執行 onboarding
docker compose run --rm openclaw-cli onboard
```

這會引導您完成：
- Gateway 設定
- Agent 配置
- Channel 設定
- Skills 安裝

### 5.2 手動設定沙箱（如果 wizard 沒有設定）

編輯 `~/.openclaw/openclaw.json`：

```bash
# 使用 CLI 容器編輯配置
docker compose run --rm openclaw-cli config edit
```

或者直接編輯檔案：

```bash
# 在 macOS 上直接編輯
nano ~/.openclaw/openclaw.json
```

加入以下配置：

```json5
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main",  // off | non-main | all
        "scope": "agent",     // session | agent | shared
        "workspaceAccess": "none",  // none | ro | rw
        "workspaceRoot": "~/.openclaw/sandboxes",
        "docker": {
          "image": "openclaw-sandbox:bookworm-slim",
          "workdir": "/workspace",
          "readOnlyRoot": true,
          "tmpfs": ["/tmp", "/var/tmp", "/run"],
          "network": "none",  // 沙箱預設無網路
          "user": "1000:1000",
          "capDrop": ["ALL"],
          "env": { "LANG": "C.UTF-8" },
          "pidsLimit": 256,
          "memory": "1g",
          "memorySwap": "2g",
          "cpus": 1
        },
        "prune": {
          "idleHours": 24,    // 24 小時未使用則清理
          "maxAgeDays": 7     // 7 天後清理
        }
      }
    }
  },
  "tools": {
    "sandbox": {
      "tools": {
        "allow": [
          "exec",
          "process",
          "read",
          "write",
          "edit",
          "sessions_list",
          "sessions_history",
          "sessions_send",
          "sessions_spawn",
          "session_status"
        ],
        "deny": [
          "browser",
          "canvas",
          "nodes",
          "cron",
          "discord",
          "gateway"
        ]
      }
    }
  }
}
```

### 5.3 重啟 Gateway 以套用設定

```bash
docker compose restart openclaw-gateway
```

## ✅ 步驟 6：驗證沙箱功能

### 6.1 檢查沙箱設定

```bash
# 使用 CLI 檢查沙箱設定
docker compose run --rm openclaw-cli sandbox explain
```

### 6.2 測試 Agent（會自動使用沙箱）

```bash
# 發送一個測試訊息（非 main 會話會自動使用沙箱）
docker compose run --rm openclaw-cli agent --message "Hello, test sandbox" --session-id "agent:main:test-session"
```

### 6.3 查看沙箱容器

```bash
# 查看正在運行的沙箱容器
docker ps | grep openclaw-sandbox

# 查看所有沙箱容器（包括已停止的）
docker ps -a | grep openclaw-sandbox
```

## 🔍 步驟 7：常用操作

### 7.1 查看 Gateway 狀態

```bash
# 查看容器狀態
docker compose ps

# 查看日誌
docker compose logs -f openclaw-gateway

# 查看最近 100 行日誌
docker compose logs --tail=100 openclaw-gateway
```

### 7.2 使用 CLI

```bash
# 執行任何 openclaw 命令
docker compose run --rm openclaw-cli <command>

# 例如：
docker compose run --rm openclaw-cli status
docker compose run --rm openclaw-cli channels status
docker compose run --rm openclaw-cli agent --message "Hello"
```

### 7.3 存取 Control UI

在瀏覽器打開：

```
http://127.0.0.1:18789/
```

如果需要 token，執行：

```bash
docker compose run --rm openclaw-cli dashboard --no-open
```

### 7.4 停止和啟動

```bash
# 停止 Gateway
docker compose stop openclaw-gateway

# 啟動 Gateway
docker compose start openclaw-gateway

# 停止並移除容器
docker compose down

# 停止並移除容器和 volumes（⚠️ 會刪除資料）
docker compose down -v
```

## 🛠️ 步驟 8：故障排除

### 8.1 Docker Socket 權限問題

如果看到 "permission denied" 錯誤：

```bash
# macOS 上通常不需要特別設定，但如果有問題：
# 確保 Docker Desktop 正在運行
# 確認 /var/run/docker.sock 存在
ls -la /var/run/docker.sock
```

### 8.2 沙箱容器無法啟動

檢查：

```bash
# 確認沙箱 image 存在
docker images | grep openclaw-sandbox

# 如果不存在，重新建立
./scripts/sandbox-setup.sh

# 檢查 Docker daemon 是否可訪問
docker compose run --rm openclaw-cli sandbox explain
```

### 8.3 配置檔案權限問題

```bash
# 確保配置目錄權限正確
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/openclaw.json
```

### 8.4 查看詳細日誌

```bash
# Gateway 日誌
docker compose logs -f openclaw-gateway

# 查看沙箱容器日誌
docker logs <sandbox-container-id>
```

## 📚 進階設定

### 啟用沙箱瀏覽器

如果需要瀏覽器工具在沙箱中運行：

1. 建立瀏覽器 image：
```bash
./scripts/sandbox-browser-setup.sh
```

2. 在配置中啟用：
```json5
{
  "agents": {
    "defaults": {
      "sandbox": {
        "browser": {
          "enabled": true,
          "image": "openclaw-sandbox-browser:bookworm-slim"
        }
      }
    }
  }
}
```

### 自訂沙箱 Image

如果需要額外的工具：

1. 建立自訂 Dockerfile：
```dockerfile
FROM openclaw-sandbox:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*
```

2. 建立 image：
```bash
docker build -t my-openclaw-sandbox -f Dockerfile.custom .
```

3. 在配置中使用：
```json5
{
  "agents": {
    "defaults": {
      "sandbox": {
        "docker": {
          "image": "my-openclaw-sandbox"
        }
      }
    }
  }
}
```

## 🔗 步驟 9：配置 Ollama（本地模型）

如果您想使用本地的 Ollama 模型（例如 ollama3.1 8bit），請按照以下步驟：

### 9.1 確認 Ollama 運行

在 macOS 主機上確認 Ollama 正在運行：

```bash
# 檢查 Ollama 是否運行
curl http://127.0.0.1:11434/api/tags

# 或檢查 Ollama 服務狀態
ollama list
```

### 9.2 確認 Ollama 監聽地址

確保 Ollama 監聽在 `0.0.0.0:11434`（允許外部連接）：

```bash
# 檢查 Ollama 監聽地址
lsof -i :11434
# 或
netstat -an | grep 11434
```

如果 Ollama 只監聽 `127.0.0.1`，需要修改 Ollama 配置或使用環境變數：

```bash
# 設定 Ollama 監聽所有介面
export OLLAMA_HOST=0.0.0.0:11434
# 然後重啟 Ollama
```

### 9.3 配置 OpenClaw 使用 Ollama

#### 方法 A：使用環境變數（自動發現）

`.env` 檔案已經包含 Ollama 設定：

```bash
OLLAMA_API_KEY=ollama-local
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

這會讓 OpenClaw 自動發現 Ollama 模型。

#### 方法 B：在配置檔案中明確設定

編輯 `~/.openclaw/openclaw.json`：

```json5
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://host.docker.internal:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-completions"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/ollama3.1:8b"
      }
    }
  }
}
```

**注意：**
- `host.docker.internal` 是 macOS Docker Desktop 的特殊主機名，用於訪問主機服務
- 如果使用 Linux Docker，可能需要使用 `172.17.0.1` 或主機的實際 IP
- URL 必須包含 `/v1` 路徑（OpenAI 兼容 API）

### 9.4 驗證 Ollama 連接

```bash
# 從容器內測試連接
docker compose run --rm openclaw-cli sh -c "curl http://host.docker.internal:11434/api/tags"

# 列出可用的 Ollama 模型
docker compose run --rm openclaw-cli models list --provider ollama

# 檢查模型狀態
docker compose run --rm openclaw-cli models status
```

### 9.5 測試使用 Ollama 模型

```bash
# 使用 Ollama 模型發送測試訊息
docker compose run --rm openclaw-cli agent \
  --message "Hello, test Ollama" \
  --session-key "agent:main:test-ollama"
```

### 9.6 故障排除

**問題：無法連接到 Ollama**

1. **確認 Ollama 正在運行**：
   ```bash
   curl http://127.0.0.1:11434/api/tags
   ```

2. **確認監聽地址**：
   ```bash
   # Ollama 應該監聽 0.0.0.0:11434，而不是只有 127.0.0.1
   lsof -i :11434
   ```

3. **測試從容器訪問**：
   ```bash
   docker compose run --rm openclaw-cli sh -c "curl http://host.docker.internal:11434/api/tags"
   ```

4. **如果 host.docker.internal 不工作**，嘗試使用主機 IP：
   ```bash
   # 在 macOS 上查看主機 IP
   ifconfig | grep "inet " | grep -v 127.0.0.1
   
   # 然後在 .env 中使用實際 IP
   OLLAMA_BASE_URL=http://192.168.x.x:11434
   ```

**問題：模型未發現**

1. **確認模型已下載**：
   ```bash
   ollama list
   ollama pull ollama3.1:8b
   ```

2. **檢查模型名稱**：
   ```bash
   # 查看實際的模型名稱
   ollama list
   
   # 在配置中使用正確的名稱
   # 例如：ollama/ollama3.1:8b 或 ollama/ollama3.1
   ```

3. **手動配置模型**（如果自動發現失敗）：
   ```json5
   {
     "models": {
       "providers": {
         "ollama": {
           "baseUrl": "http://host.docker.internal:11434/v1",
           "apiKey": "ollama-local",
           "api": "openai-completions",
           "models": [
             {
               "id": "ollama3.1:8b",
               "name": "Ollama 3.1 8bit",
               "reasoning": false,
               "input": ["text"],
               "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
               "contextWindow": 8192,
               "maxTokens": 81920
             }
           ]
         }
       }
     }
   }
   ```

## 🎉 完成！

現在您已經成功在 macOS 上使用 Docker 安裝了 OpenClaw，並啟用了：
- ✅ 沙箱安全模式
- ✅ Ollama 本地模型支援

**重要提醒：**

1. ✅ 沙箱模式已啟用：非 `main` 會話的工具會在 Docker 容器中執行
2. ✅ Docker socket 已掛載：Gateway 可以創建和管理沙箱容器
3. ✅ Ollama 已配置：可以使用本地模型（ollama3.1:8b）
4. ✅ 安全隔離：工具執行與主機系統隔離

**下一步：**

- 設定 Channels（WhatsApp、Telegram 等）
- 安裝 Skills
- 開始使用您的 AI 助理！

如有問題，請查看：
- [官方文檔](https://docs.openclaw.ai)
- [Docker 安裝指南](https://docs.openclaw.ai/install/docker)
- [沙箱文檔](https://docs.openclaw.ai/gateway/sandboxing)
- [Ollama 提供者文檔](https://docs.openclaw.ai/providers/ollama)
