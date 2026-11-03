# Web Video Presentation · 使用说明与踩坑记录（Windows / WorkBuddy）

[English](VIDEO-GUIDE.md) | **中文版**

> 本文件是 xhs-video-agent 的组成部分；示例数据来自作者账号，仅用于说明方法。
>
> 本文件是项目侧的补充说明，记录本机环境约定、标准流程和实战踩坑。
> Skill 本体在 `skills\web-video-presentation\`，**不要改动里面的文件**（方便以后按版本升级覆盖）。

---

## 1. 这是什么

- **名称**：web-video-presentation v1.2.2（pinned 版本，SHA256 已校验）
- **来源**：https://github.com/ConardLi/garden-skills/ （UP 主：code秘密花园）
- **本质**：把文章 / 口播稿做成一个 **16:9 的 Vite + React + TS 网页**，点击推进、每步独占整屏，录屏就是成片。不是 AI 生成视频，而是 AI 写网页代码，字体/配色/动效/停留时间全部可精确控制。
- **产出物**：一个可运行的网页项目 + 按步骤切分的口播音频（可选）。

**和小红书线的分工**：

| 内容线 | 工具 | 规格 | 分发平台 |
|---|---|---|---|
| 图文线 | redbook-creator-publish + xiaohongshu-mcp | 3:4 竖版图文 | 小红书 |
| 视频线 | web-video-presentation（本文件） | 16:9 横屏录屏 | B站 / 视频号 / YouTube |

两条线共用"真诚学习者"人设，互不干扰。CS50 / CS188 的画图讲解类内容特别适合视频线。

---

## 2. 本机环境约定（重要，先看）

### 2.1 bash 用 Git Bash，不要用 WSL

Windows 上直接敲 `bash` 默认可能进入 **WSL**（`C:\Windows\system32\bash.exe`），在 WSL 里操作挂载盘项目会非常慢，环境也是另一套。

请用 **Git for Windows** 自带的 Git Bash（安装后在开始菜单搜索 "Git Bash"，或使用 `git-bash.exe`）。它能直接调用 Windows 原生 node/npm。

**给 AI 助手的固定指令（每次做视频时在对话里声明一次）**：

> 本项目涉及 web-video-presentation 的所有 bash 脚本，统一用 Git Bash 执行；node/npm 用 Windows 原生版本，不要走 WSL。

### 2.2 让 WorkBuddy 加载新 skill

外部拷入的 skill 不会被自动感知。安装 / 升级 skill 后：

1. 完全退出 WorkBuddy（**包括系统托盘进程**）
2. 重新打开，或在项目里开新会话

### 2.3 每个视频用独立子目录

脚手架脚本要求目标目录为空（非空会中止），**不要**在项目根直接建。建议：

```
<repo-root>\videos\<视频英文短名>\
├── article.md        # 原始文章
├── script.md         # 口播稿（AI 生成）
├── outline.md        # 开发计划（AI 生成）
└── presentation\     # 脚手架生成的网页项目
```

### 2.4 TTS 用免费的 edge-tts（无需 API key）

Skill 默认 TTS 是 MiniMax CLI（mmx），**不装**。用官方预留的 edge-tts provider（微软 Edge 语音接口，免费）：

```powershell
pip install edge-tts
```

装完验证：`edge-tts --version`。常用中文音色：

- `zh-CN-YunxiNeural`（男声，默认）
- `zh-CN-XiaoxiaoNeural`（女声）

若 Git Bash 里提示找不到 `edge-tts` 命令，确认 Python 的 `Scripts` 目录（`python -m site --user-base` 下的 `Scripts`，或 Anaconda 安装目录下的 `Scripts`）在 PATH 中，重开终端即可。

---

## 3. 标准工作流速查

```
Phase 0 调研（项目级新增，见 WORKFLOW.md 3.1）
  常规线 / CS188 线先产出 facts.md 调研卡（信源 + 关键数据 + 抽象概念→视觉比喻）；
  调研不实不动笔。gh-daily 线豁免（fetch.py 选题卡即调研层）。
  ▼
Phase 1 内容编写
  facts.md + 原始文章 → AI 一次产出 script.md（口播稿）+ outline.md（章节/步骤计划
  + 分镜要素：每步的转场方式 / 视觉焦点移动 / 阅读保护时长）
  ▼
【检查点 1 · 硬节点】一次对齐 6 件事：
  ① 调研卡  ② 稿子  ③ 大纲  ④ 主题（23 选 1）  ⑤ 素材  ⑥ 开发模式
  ▼
Phase 2 网页开发
  脚手架建项目 → 第 1 章必须一次做完整
  ▼
【检查点 2 · 硬节点】人工验收第 1 章（视觉/节奏/AI 味），不可跳过
  ▼
  第 2~N 章，三种模式：
    A 逐章确认（默认，最稳）
    B 顺序开发（不暂停，最后统一验收，适合无 subagent 的环境）
    C subagent 并行（最快，但章节间风格会有差异）
  ▼
【检查点 3 · 硬节点】要不要合成音频？
  ▼
Phase 3 音频合成（可选）：extract-narrations → edge-tts 批量合成 → public/audio/
  ▼
Phase 4 录屏：?auto=1 一镜到底
```

**四份文件的作用（AI 的"外部记忆"）**：

- `facts.md`：调研卡——信源清单、关键数据（带出处）、抽象概念→视觉比喻映射。常规/CS188 线必备，**调研不实不动笔**；gh-daily 线豁免（fetch.py 选题卡即调研层）
- `article.md`：原始素材，**不要删**，开发画面时回这里抽细节
- `script.md`：口播稿，决定节奏（顺序不能乱）
- `outline.md`：开发计划，管章节切分、每步屏幕内容、信息密度、分镜要素（转场方式/视觉焦点移动/阅读保护时长），**不规定具体动画实现**

**唯一真相源**：每章目录下的 `narrations.ts`。它的数组长度 = 该章 step 数 = 音频文件数。改了 step 数量后，还要 bump `src/hooks/useStepper.ts` 里的 STORAGE_KEY 版本号（如 v4 → v5），否则浏览器记住的播放进度会错位。

**节拍表与风格切换（详见 `WORKFLOW.md` 3.7 / 3.8）**：
- **节拍表（毫秒级）**：`script.md` 以 `---` 分隔节拍（一拍 = 一 step），定稿后产出 `beats.json`（`step_id/chapter/start_ms/dur_ms/text`）。时长优先取 TTS 实测（`audio-segments.json` + `marks.json`），估时必须标注；章节代码禁硬编码毫秒/秒数，对轨一律读 `marks.json`
- **换风格只换提示词**：时间轴/动作骨架/step 划分固定，只改 `src/styles/tokens.css`（主题 token）与章节视觉提示词，即可整片换皮（剪纸风/蓝图/微缩/像素等）；换风格不得改 step 数

---

## 4. 录屏三种模式（踩坑重灾区，务必记住）

| 打开方式 | 行为 |
|---|---|
| 直接打开 `localhost:5173` | **Manual（默认）：点击/方向键推进，不播任何音频** |
| URL 加 `?audio=1`，或按 `M` 键 | Audio：进入步骤自动播音，但**仍需手动点击**推进 |
| URL 加 `?auto=1` | Auto：播音 + 播完自动推进，录屏用；首次需**按一次 Space** 启动（绕过浏览器自动播放限制） |

- 右上角有个**隐藏的模式切换按钮**，鼠标 hover 才出现（故意隐藏，保证录屏画面干净）；底部边缘 hover 出进度条。
- Auto 模式严格按"音频结束 + 阅读保护时间"推进（模板默认 **1500ms**，2026-10-17 起；整片可调 `?auto=1&trail=800`，录屏脚本用 `TRAIL_MS` 环境变量透传），没有等动画的兜底。**某步动画被切掉一半 = 那段口播太短**，回章节代码改：加长口播 / 拆 step / 调快动画。对轨不受 trail 影响：`build_master.py` 按 marks.json 实测切换时刻摆音频。
- Auto 模式录屏全程不用点鼠标：全屏（F11）→ 开录屏软件 → 按一次 Space → 播完停录 → 剪掉头尾。

### 实战踩坑①：页面点着没声音

首次跑通后音频文件都在，但点页面就是没声，查了很久。原因：**默认就是 Manual 模式，设计上不播音**，不是 bug。录屏直接用 `?auto=1`，或按 `M` 切到 Audio。SKILL 规程里写了"AI 应在音频合成后主动告知 ?auto=1"，但 AI 当时没执行这条——所以这种关键操作要自己记住，不能指望 AI 每次都提示。

---

## 5. 音频合成流程（edge-tts 免费方案）

```bash
cd presentation
npm run extract-narrations     # 扫描所有章节 narrations.ts → audio-segments.json
                               # 先人工扫一眼 JSON，确认文本无误
```

然后把 Skill 自带的 edge-tts 代码片段保存为 provider（AI 可代劳）：

- 片段位置：`skills\web-video-presentation\templates\scripts\tts-providers\README.md` 中"edge-tts"一节
- 操作：把片段复制为 `presentation\scripts\tts-providers\edge-tts.sh`（三函数契约：tts_check / tts_install_help / tts_synthesize，片段已写全，直接可用）
- 合成：

```bash
PRESENTATION_TTS=edge-tts npm run synthesize-audio
# 指定音色：
PRESENTATION_TTS=edge-tts PRESENTATION_TTS_VOICE=zh-CN-XiaoxiaoNeural npm run synthesize-audio
# 增量合成：已生成的 mp3 自动跳过；改了文案想重跑加 -- --force
```

### 实战踩坑②：AI 让装 MiniMax CLI

AI 按默认流程让安装 `mmx`（MiniMax 官方 CLI，要 API key/额度）。不用装——Skill 的 TTS 是可插拔设计，edge-tts 是官方文档里备好的免费替代，Windows 下 Git Bash 可直接运行。

### 实战踩坑③：排版问题一点点调

全部章节做完后排版有细碎问题，反复对话调整很慢。Skill 的官方原则叫"反馈修复最小切片"：

- 只改最小单元（节奏/视觉/代码分层定位问题），不要一句话让 AI 重做整章
- 但**把问题攒一批一次性提**，不要一问一答——每次对话 AI 都要重新加载整个项目上下文，最费积分

---

## 6. 积分成本与省钱清单

首次实战（2026-10，案例《邮件发出后的600ms》，分 7 个章节串行完成，没用 subagent）：

- 实耗 **约 400 积分 ≈ 15.2 元**（1000 积分 / 38 元）
- 若一次并行跑完估算 300 积分以内
- 串行更贵的原因：每开发一章 AI 都要重新加载一次很厚的 `CHAPTER-CRAFT.md`（原则/决策树/反 AI 味/自检清单），7 章 = 7 次重复加载

但串行不是错——没有开发经验时，每章人工验收能把返工限制在单章内，不会全军覆没；并行省的是积分，赌的是第一章锚点足够稳。

**省钱要点（按收益排序）**：

1. **检查点 1 的 6 件事一次认真确认**，尤其调研卡、稿子和大纲。后期改稿是连锁成本：script → narrations.ts → 音频重新合成 → STORAGE_KEY。
2. **第 1 章验收往狠里挑**：紫粉渐变、圆角彩色边框、假插画、emoji、无脑入场动画这些"AI 味"在第一章全部掐掉，后面章节会照第一章的锚点走。
3. 修改意见攒一批、一次提（见踩坑③）。
4. 熟练后再试模式 C 并行（WorkBuddy 若支持 subagent），第一章仍然必须串行 + 人工验收。
5. 每章必须有 CSS/SVG/Canvas 视觉演示，禁纯文字；清单列表 1 项 = 1 step，禁一次全展示——开工时盯 AI 做到，比重做省钱。

---

## 7. 常用命令速查

```bash
# 在 Git Bash 中执行；skills/ 为 web-video-presentation 的安装位置
# 列出 23 个主题
bash skills/web-video-presentation/scripts/scaffold.sh --list-themes

# 脚手架（在 videos/<视频名> 目录的上一级执行，目标目录须不存在或为空）
bash skills/web-video-presentation/scripts/scaffold.sh ./presentation --theme=blueprint
```

```bash
cd presentation
npm run dev                 # 开发服务器（默认 5173/5174）
npx tsc --noEmit            # 类型检查，每章完工跑一次
npm run extract-narrations  # 抽口播文本 → audio-segments.json
PRESENTATION_TTS=edge-tts npm run synthesize-audio   # 免费合成音频
```

主题推荐（技术学习类内容）：`blueprint` 蓝图（工程图纸风，适合架构/拆解）、`chalk-garden` 粉笔花园（课堂讲解风）、`terminal-green` 终端绿（代码演示）、`forest-ink` 森林墨（沉稳叙事）。换主题只需覆盖 `src/styles/tokens.css` 一个文件。

---

## 8. 状态清单

- [x] Skill v1.2.2 安装（95 个文件，23 主题，SHA256 校验通过）
- [x] Git Bash 5.2 下 scaffold 脚本实测可运行
- [x] Windows 原生 node/npm 链路确认
- [ ] `pip install edge-tts`（首个视频进入音频阶段时装）
- [ ] WorkBuddy 完全重启后确认 skill 被识别
- [ ] 首个视频试跑（建议用一篇已写好的 CS50/CS188 笔记）

## 9. 关键路径

- 规程主文件：`skills\web-video-presentation\SKILL.md`
- 章节开发单一必读：`skills\web-video-presentation\references\CHAPTER-CRAFT.md`
- 音频流程：`skills\web-video-presentation\references\AUDIO.md`
- 录屏说明：`skills\web-video-presentation\references\RECORDING.md`
- TTS provider 片段（含 edge-tts）：`skills\web-video-presentation\templates\scripts\tts-providers\README.md`
- Skill 在线文档：https://github.com/ConardLi/garden-skills/blob/main/skills/web-video-presentation/README.md
