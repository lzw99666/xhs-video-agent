# templates — 复制到哪里

[English](README.md) | **中文版**

这些文件是**骨架**，不是可直接发布的成品。复制后按内容替换。

| 模板 | 复制到 | 说明 |
|---|---|---|
| `account.md` | `<repo-root>/account.md` | 账号设定（人设 / 受众 / 内容线 / 红线）。所有创作前先读。 |
| `log.md` | `<repo-root>/log.md` | 发布记录唯一真相源；`validate.ps1` 的"当日篇数"读这里。 |
| `episode/` | `<repo-root>/videos/<episode-name>/` | 一期视频的五件套：调研卡 / 创作意图 / 口播稿 / 分镜大纲 / 文案自检。 |

## 还需要哪些运行时文件

- `.cheat-state.json`：由 `cheat-on-content` 的 `/cheat-init` 生成（含预测哈希锁）。
- `backlog.json`：想跑无人值守心跳时再建；只跑单条视频可以不要。
- `predictions/`、`scripts/`、`candidates.md`：同样由 `/cheat-init` 建立。

## 复制命令

```powershell
# 账号与日志（只做一次）
Copy-Item templates\account.md account.md
Copy-Item templates\log.md log.md

# 新一期
New-Item -ItemType Directory -Force videos\my-ep01
Copy-Item templates\episode\* videos\my-ep01\
```

> 骨架阶段的 `check.ps1` 会报警（文件还没写满），这是预期行为；内容定稿后再跑闸门。
