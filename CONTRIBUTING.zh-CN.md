# 参与贡献

[English](CONTRIBUTING.md) | **中文版**

感谢你愿意改进 xhs-video-agent。这个仓库**首先是一套写清楚的流程，其次才是代码**——因此一次改动通常意味着文档、闸门、示例要一起更新。

## 你可以贡献什么

- **报告 bug**：`docs/WORKFLOW.md` 里某一步的行为与描述不符、闸门误判、脚本在干净机器上跑不起来。
- **提功能需求**：新的拍型、新的闸门检查、新的 TTS provider、新的发布适配器。
- **文档 / 翻译**：英文版与 `*.zh-CN.md` 版本出现偏差，或某段说明过时、看不懂。
- **示例**：在 `examples/` 下新增一条完整视频的文本资产（只放文字，不放视频文件）。

## 动手之前

1. 先读 [`README.zh-CN.md`](README.zh-CN.md) 和 [`docs/WORKFLOW.zh-CN.md`](docs/WORKFLOW.zh-CN.md)。多数"bug"其实是前置条件没满足。
2. 搜一下已有的 issue 和 PR，避免重复劳动。
3. 超过一个 bugfix 规模的改动，请先开 issue，说清楚**你卡在哪一步**、**它挡住了流程的哪个环节**。小而聚焦的 PR 比大重构好审得多。

## Fork 与 PR 流程

```bash
# 1. 在 GitHub 上 fork，然后克隆你的 fork
git clone https://github.com/<your-name>/xhs-video-agent.git
cd xhs-video-agent

# 2. 保留一个指向上游的 remote
git remote add upstream https://github.com/lzw99666/xhs-video-agent.git

# 3. 从最新的 main 切分支（不要直接推 main）
git fetch upstream
git checkout -b fix/gate-audio-check upstream/main

# 4. 改完提交，commit message 带 scope
git add -A
git commit -m "fix(gate): audio check now skips beats with no narration"

# 5. 推到你的 fork，然后向 main 提 PR
git push -u origin fix/gate-audio-check
gh pr create --base main --title "fix(gate): audio check now skips beats with no narration"
```

仓库还有一个长期存在的集成分支 **`feature`**，用于"需要多次提交才能进 main"的较大改动。跨多步的改动从它切分支（例如新增 TTS provider），PR 回 `feature`，整块验证通过后再由 `feature` 合入 `main`。

## 一个好 PR 应该包含什么

- **一个 PR 只做一件事。** 不要把闸门修复和 README 重写混在一起。
- **说明原因。** PR 描述要讲"今天哪里会坏"，而不只是"我改了什么"。
- **验证输出。** 贴出你跑过的命令与退出码（见下）。
- **文档同步。** 改了闸门，就同时更新 `docs/WORKFLOW.md` 和 `docs/WORKFLOW.zh-CN.md`；给模板加字段，就同步更新 `templates/` 的中英两份。
- **不要提交隐私数据。** `account.md`、`log.md`、`.cheat-state.json`、`backlog.json`、预测文件、cookies、`session.json`、指标数据，以及任何 `*.mp4` 都不进仓库。

## 本地验证

开 PR 前请跑完下面这些；仓库没有配 CI，评审依赖你贴的输出。

```powershell
# PowerShell 语法与 BOM 规范
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\normalize-bom.ps1 -Check
Get-ChildItem tools -Recurse -Filter *.ps1 | ForEach-Object {
  $e = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$e) | Out-Null
  if ($e) { "$($_.Name): $($e[0].Message)" }
}

# Python / Node 语法
python -X utf8 -m py_compile tools\record\build_master.py tools\record\verify_sync.py `
  tools\pipeline\compress-audit.py tools\pipeline\blind-read-check.py `
  tools\research\fetch_sources.py tools\cover\cover.py
node --check tools\record\record.mjs
node --check tools\record\shot.mjs
node --check tools\metrics\login.js
node --check tools\metrics\pull.js

# 示例必须仍然通过闸门
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 `
  -ProjectDir examples\ep11-sampling -Gate pre-code
# 预期：pass=19 warn=1 fail=0，EXIT=0
# 唯一的 WARN 来自 C14：英文示例稿估算 185s，比 180s 硬上限多 5s

# 文档必须保持双语
# （每个英文文档都有对应的 *.zh-CN.md，且顶部有语言切换行）
```

如果改动涉及闸门，再跑一遍本地能跑的其它闸门：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 -ProjectDir examples\ep11-sampling -Gate pre-script
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 -ProjectDir examples\ep11-sampling -Gate delivery
```

（`delivery` 在示例上预期会失败，因为示例没有成片和音频——这是真实缺件，不是回归。）

## 风格约定

- **提交信息**：`type(scope): summary`，如 `fix(gate): ...`、`docs(workflow): ...`、`feat(tts): ...`。类型：`feat`、`fix`、`docs`、`refactor`、`test`、`chore`。
- **代码注释**：所有脚本统一英文。
- **文档**：主文件英文，中文放在 `.zh-CN.md` 兄弟文件里。不要只改一边。
- **路径**：相对仓库根，或用环境变量覆盖（见 README 第 8 节）。禁止硬编码绝对路径、用户名、机器相关配置。
- **依赖**：不要内联第三方 skill 源码；指向上游链接，并同步更新 README 的依赖表。

## 评审流程

- 维护者通常会在几天内 review；一周没动静可以在 PR 里 ping。
- 可能会追问你修的失败场景——可复现步骤比长篇解释更有用。
- 纯文档 PR 通常很快合入；闸门改动必须保证示例工程仍然通过。

## 许可

提交即表示你同意你的贡献以 [MIT License](LICENSE) 授权。
