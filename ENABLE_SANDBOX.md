# 重新啟用 Sandbox 安全模式

## 步驟 1：重新構建 Docker 映像（包含 Docker CLI）

```bash
cd /Users/eric/gitSource/openclaw

# 使用環境變數安裝 Docker CLI
export OPENCLAW_DOCKER_APT_PACKAGES="docker.io"

# 重新構建映像
docker build -t openclaw:local -f Dockerfile .

# 停止現有容器
docker compose down

# 重新啟動
docker compose up -d openclaw-gateway
```

## 步驟 2：驗證 Docker CLI 已安裝

```bash
docker compose exec openclaw-gateway docker --version
docker compose exec openclaw-gateway docker ps
```

如果這兩個命令都成功，Docker CLI 已正確安裝。

## 步驟 3：重新啟用 Sandbox

```bash
# 方法 1：使用 config 命令
docker compose run --rm openclaw-cli config set agents.defaults.sandbox.mode "non-main"

# 方法 2：直接編輯配置檔案
# 編輯 ~/.openclaw/openclaw.json，將 "mode": "off" 改為 "mode": "non-main"
```

## 步驟 4：重啟 Gateway

```bash
docker compose restart openclaw-gateway
```

## 步驟 5：驗證 Sandbox 已啟用

```bash
docker compose run --rm openclaw-cli sandbox explain
```

應該看到：
```
Effective sandbox:
  mode: non-main scope: agent perSession: false
```

## 如果 Docker CLI 安裝失敗

### macOS Docker Desktop 的特殊情況

在 macOS 上，Docker Desktop 可能不需要在容器內安裝 Docker CLI。可以嘗試：

1. **檢查 Docker socket 是否可訪問**：
   ```bash
   docker compose exec openclaw-gateway ls -la /var/run/docker.sock
   ```

2. **測試直接訪問**：
   ```bash
   docker compose exec openclaw-gateway sh -c 'echo "test" | nc -U /var/run/docker.sock'
   ```

3. **如果 socket 可訪問但 CLI 不可用**，可能需要：
   - 掛載主機的 Docker 二進制文件（不推薦，可能版本不兼容）
   - 或使用 Docker API 直接調用（需要修改代碼）

## 臨時安全措施（在修復期間）

如果暫時無法啟用 sandbox，可以通過工具策略限制風險：

```json5
{
  "tools": {
    "deny": [
      "exec",      // 禁止執行命令（最危險）
      "process",   // 禁止進程管理
      "browser",   // 禁止瀏覽器
      "gateway"    // 禁止 Gateway 操作
    ],
    "allow": [
      "read",
      "write",
      "edit",
      "sessions_list",
      "sessions_history"
    ]
  }
}
```

## 總結

- ✅ **推薦**：修復 Docker 權限並啟用 sandbox（`mode: "non-main"` 或 `mode: "all"`）
- ⚠️ **臨時**：如果無法啟用 sandbox，使用嚴格的工具策略限制風險
- ❌ **不推薦**：長期使用 `sandbox.mode: "off"` 而不限制工具
