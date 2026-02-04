# 啟用沙箱模式 - 快速指南

## 方法 1：直接編輯配置檔案（推薦）

編輯 `~/.openclaw/openclaw.json`：

```bash
# 在 macOS 上直接編輯
nano ~/.openclaw/openclaw.json

# 或使用 VS Code
code ~/.openclaw/openclaw.json
```

在 `agents.defaults` 區塊中加入 `sandbox` 配置：

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/ollama3.1:8b"
      },
      "sandbox": {
        "mode": "non-main",  // off | non-main | all
        "scope": "agent",
        "workspaceAccess": "none",
        "docker": {
          "image": "openclaw-sandbox:bookworm-slim"
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
          "gateway",
          "web_search",
          "web_fetch"
        ]
      }
    }
  }
}
```

## 方法 2：使用 config set 命令

```bash
# 啟用沙箱模式（非 main 會話）
docker compose run --rm openclaw-cli config set agents.defaults.sandbox.mode "non-main"

# 設定沙箱 image
docker compose run --rm openclaw-cli config set agents.defaults.sandbox.docker.image "openclaw-sandbox:bookworm-slim" --json

# 設定工具策略（需要 JSON 格式）
docker compose run --rm openclaw-cli config set tools.sandbox.tools.deny '["browser","web_search","web_fetch"]' --json
```

## 方法 3：使用配置精靈

```bash
docker compose run --rm openclaw-cli config
```

然後選擇相關的配置選項。

## 重啟 Gateway

修改配置後，必須重啟 Gateway：

```bash
docker compose restart openclaw-gateway
```

## 驗證沙箱設定

```bash
docker compose run --rm openclaw-cli sandbox explain
```

應該會看到 `mode: non-main` 或 `mode: all`。
