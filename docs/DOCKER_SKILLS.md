# 讓 Skills 在 Docker 裡可用

在 Docker 裡多數 skill 會顯示 **missing**，主因是：(1) 只允許 macOS（`os: ["darwin"]`）；(2) 需要主機才有的 CLI（如 `memo`、`remindctl`）。底下是幾種讓它們在 Docker 裡「可用」或「至少顯示 ready」的做法。

---

## 方法一：在設定裡無法改

`~/.openclaw/openclaw.json` 的 `skills.entries.<name>` **只能**：

- `enabled: true/false` 開關
- `env` / `apiKey` 補足「需要某個環境變數」的 skill

**不能**用設定覆寫：

- `os`（是否只限 darwin）
- `requires.bins`（需要哪些指令）

所以「改成 Docker 可用」一定要動到 **skill 檔案** 或 **容器環境**。

---

## 方法二：改你本地的 skill 副本（`~/.openclaw/skills/`）

你把 skills 放在 `~/.openclaw/skills/` 時，改的是**你這份** SKILL.md，不會動到內建或 repo 裡的版本。

### 2a) 強制納入（不檢查條件）：`always: true`

在該 skill 的 **metadata.openclaw** 裡加上 `"always": true`，該 skill 就會被當成 **ready**，不再檢查 `os` / `bins` / `env`。

**注意**：若 skill 內容會叫 `memo`、`remindctl` 等容器裡沒有的指令，執行時還是會失敗，只是列表上會顯示 ready。

適合：你想在 Docker 裡「先看到」這個 skill，或該 skill 多半用通用工具（curl、bash 等），只有部分進階才用 macOS 專用指令。

範例（apple-notes 的 metadata 改成）：

```yaml
metadata:
  {
    "openclaw":
      {
        "emoji": "📝",
        "always": true,
        "os": ["darwin"],
        "requires": { "bins": ["memo"] },
        ...
      },
  }
```

把 `"always": true` 加進去後，在 Docker 裡就會變 ready；若容器沒裝 `memo`，真的用到時會 command not found。

### 2b) 放寬 OS：讓 Linux 也通過

若某個 skill 在 Linux 上「有對應做法」（例如改用別的 CLI 或 API），可以：

- 把 `"os": ["darwin"]` 改成 `"os": []`（不限制），或
- 改成 `"os": ["darwin", "linux"]`

並視需要改 `requires.bins`（例如改成容器裡會裝的指令）。這樣在 Docker（Linux）裡就會通過檢查、變成 ready。

---

## 方法三：在 Docker 裡裝齊指令（bins）

若 skill **沒有** `os: ["darwin"]`，只缺 `requires.bins`，只要在映像裡裝對應套件，就會變 ready。

### 用現有 ARG 一次裝多個（Debian/Bookworm）

Dockerfile 已支援：

```dockerfile
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
```

建映像時可傳入多個套件，例如：

```bash
docker build --build-arg OPENCLAW_DOCKER_APT_PACKAGES="curl jq gh" -t openclaw:local .
```

或在 `.env` 裡設（若 compose 有把這 ARG 傳下去）：

```bash
OPENCLAW_DOCKER_APT_PACKAGES=docker.io curl jq gh
```

常見、且常被 skill 要求的指令（多數在 Debian 有對應套件）：

- `curl` — 通常已有；weather 等會用
- `jq` — `apt install jq`
- `gh` — `apt install gh`（github skill）

裝好後，**不需要**改 SKILL.md，該 skill 就會從 missing 變 ready（只要沒有 `os: ["darwin"]`）。

### 建議：先挑「只差 bins」的 skill

這類在 Docker 裡只要裝 bins 就可用，例如：

- **weather** — 需 `curl`（映像常有）
- **github** — 需 `gh`，`apt install gh` 即可
- 其他在 SKILL.md 裡只有 `requires.bins`、沒有 `os: ["darwin"]` 的，都可先查對應的 apt 套件名，塞進 `OPENCLAW_DOCKER_APT_PACKAGES` 或 Dockerfile 裡安裝。

---

## 方法四：做「Docker 專用」skill 副本

對**本質上只適合 macOS** 的 skill（例如 Apple Notes、Things、Reminders），若要在 Docker 裡「有類似功能」：

1. 在 `~/.openclaw/skills/` 下複製一份，改名字（例如 `apple-notes-docker`）。
2. 在副本的 SKILL.md 裡：
   - 拿掉或改成 `"os": ["linux"]` / `"os": []`，
   - 把 `requires.bins` 改成你在 Docker 裡會裝的指令（或留空、改用 `always: true`），
   - 內文改成用 Linux 可用的方式（例如用 API、用別的 CLI、或說明「此 skill 在 Docker 僅部分支援」）。
3. 這樣就有一個「Docker 版」skill，不影響原本的 macOS 版。

---

## 怎麼看某個 skill 缺什麼

```bash
docker compose run --rm openclaw-cli skills info <skill-name>
docker compose run --rm openclaw-cli skills check
```

`skills check` 會列出每個 skill 缺的 bins / env / config / os，方便決定要改 metadata 還是裝套件。

---

## 總結

| 目標 | 做法 |
|------|------|
| 讓 skill 在列表變 ready、但執行可能失敗 | 在 `~/.openclaw/skills/<name>/SKILL.md` 的 metadata 加 `"always": true` |
| 讓「只差指令」的 skill 在 Docker 可用 | 在映像裡用 `OPENCLAW_DOCKER_APT_PACKAGES` 或 Dockerfile 裝對應 bins（如 `gh`、`jq`） |
| 讓限制 darwin 的 skill 在 Linux 也通過 | 在本地副本改 `os`、必要時改 `requires.bins` 或內文 |
| 在 Docker 提供「類 macOS 功能」 | 在 `~/.openclaw/skills/` 做 Docker 專用副本，改說明與 requires |

設定檔**不能**改 `os` 或 `requires.bins`，一定要改 skill 檔案或容器環境。
