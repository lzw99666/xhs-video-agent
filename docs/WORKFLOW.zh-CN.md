# 小红书运营工作流（整合版）

[English](WORKFLOW.md) | **中文版**

> 本文件是 xhs-video-agent 的组成部分；示例数据来自作者账号，仅用于说明方法。
>
> 本文件把小红书两条内容线（图文 / 视频）+ 发布 + 复盘 串成一份端到端可执行说明。
> 账号设定以 `account.md` 为准，发布记录以 `log.md` 为准，二者是本流程的"外部记忆"。
> 最后整合：2026-10-11（新增 cheat-on-content 校准循环层，见第 8 节）。

---

## 0. 总览

| 内容线 | 创作工具 | 产物规格 | 分发平台 | 发布方式 |
|---|---|---|---|---|
| 图文线 | `redbook-creator-publish` skill + Pillow 出图脚本 | 3:4 竖版 1080×1440 图文 | 小红书 | `xiaohongshu-mcp` → `publish_content` |
| 视频线 | `web-video-presentation` skill + `tools/record` 出片流水线 | 3:4 竖版 1080×1440 视频 | 小红书（也兼容 B站 16:9） | `xiaohongshu-mcp` → `publish_with_video` |

两条线共用"真诚学习者"人设（`account.md`），互不干扰。**所有发布动作必须人工确认**（skill 硬约束 + MCP 写操作闸门）。

---

## 1. 目录结构

```
<repo-root>\
├── account.md            # 账号档案（唯一设定来源，每次创作前必读）
├── log.md                # 运营日志（发布记录 + 周复盘，每次发布后追加）
├── WORKFLOW.md           # 本文件
├── VIDEO-GUIDE.md        # 视频线补充说明（环境约定 / 踩坑）
├── DEPLOY.md             # MCP 部署说明（启动 / 连接器 / 登录）
├── assets\               # 通用素材（banner 等）
├── cache\                # 运行时缓存（登录二维码等）
├── posts\                # 图文发布包（按日期分目录，含 Pillow 出图脚本）
│   └── 2026-10-09-personal-agent\
│       ├── note-01.md / note-02.md   # 发布包（标题/正文/配图清单/标签/风险）
│       └── gen_images.py / gen_images_02.py   # 1080×1440 封面/内页生成脚本
├── skills\
│   ├── redbook-creator-publish\      # 图文创作 skill（来源 lobehub/rov639 v1.0.0）
│   ├── web-video-presentation\       # 视频线 skill（v1.2.2，已本地加 3:4 变体）
│   ├── cheat-on-content\             # 内容校准预测循环（XBuilderLAB v0.1.0，14 子 skill，见第 8 节）
│   └── atutun-xhs-cover\             # 爆款封面提示词生成（panggungunvibe/atutun-xhs-cover，阿囤囤风格；产出封面图提示词，喂 text_to_image 出 1080×1440 封面）
├── tools\record\         # 视频出片流水线（本项目自写，非 skill 自带）
│   ├── record.mjs        # Playwright 无头录屏（?auto=1）
│   ├── build_master.py   # 拼音频 + 合成 mp4（爆音 bug 已修）
│   └── verify_sync.py    # 音画同步互相关校验
├── tools\cover\          # 通用封面渲染工具（所有视频线共用，非 skill 自带）
│   ├── cover.py          # 阿囤囤风格 HTML/CSS → Playwright 截图出 1080×1440 封面
│   └── README.md         # 用法与参数
├── videos\               # 视频线项目（每个视频独立子目录）
│   └── personal-agent-deep-dive\     # 已发布第 1 支（personal-agent-vertical.mp4）
└── mcp\                  # 小红书 MCP 服务（B站线已于 2026-10-10 下线删除）
    ├── xiaohongshu-mcp.exe / start-mcp.ps1 / xiaohongshu-login.exe
    └── cookies.json      # 登录态（长期有效，失效重扫）
```

---

## 2. 图文线流程

### 2.1 创作（redbook-creator-publish）
每次创作前**先读 `account.md` + `log.md`**，按人设 / 选题策略 / 红线产出：
1. **选题**：用户给或用 AI 调研当下 AI/工具/产品话题，先给选项再草稿。
2. **草稿**：标题 ≤ 20 中文字、强钩子开头、3–6 个短段、可落手建议、配图建议、标签。
3. **配图计划**：每张图定义 用途 / 卡面文案 / 风格 / 比例 / 来源（AI 生成 or 截图）。
4. **发布包**：结构化返回 标题 / 正文 / 图片清单 / 标签 / 首条评论 / 风险提示。

### 2.2 出图（Pillow 脚本化，统一视觉）
竖版 3:4 = **1080×1440**，浅色底 + 克莱因蓝标签块，微软雅黑。
- 脚本：`posts/2026-10-09-personal-agent/gen_images.py`（封面/内页一键生成）
- 色板：底 `#F5F5F0`、正文 `#1A1A1A`、辅助灰 `#8A8A85`、主色 `#2B5BFF`、卡片白 `#FFFFFF`
- 字体：`C:/Windows/Fonts/msyhbd.ttc`（粗）、`msyh.ttc`（常规）
- 运行（Windows）：`python posts\2026-10-09-personal-agent\gen_images_02.py` → 输出到 `images/`
- 概念示意图可用 AI 生成；代码/实操类**优先用公网可核实素材**（官方文档 / 公开教程页面截图，**注明来源**），本地笔记截图仅作**可选**补充。

### 2.3 发布（见第 4 节 MCP）
`publish_content(title, content[正文不手写#标签], 图片绝对路径列表, tags[])`——话题标签一律走 `tags[]` 数组参数（3~6 个领域/分类标签，平台渲染为 #话题 用于垂类推流），不要在正文里手写。

---

## 3. 视频线流程

### 3.1 标准流程（web-video-presentation）
```
Phase 0 调研（2026-10-17 新增，借鉴舞台剧流水线"工序一"）：
        常规线 / CS188 线先产出 facts.md 调研卡——信源清单 + 关键数据（带出处）+
        抽象概念→视觉比喻映射。"调研不实不动笔"：facts.md 未定稿禁止写 script。
        【素材获取（2026-10-18 新增）】素材以**公网检索**为首选（官方文档 / 公开教程 /
        论文），强制**多源交叉**：≥2 个独立来源、其中 ≥1 个公网；本地学习资料仅为
        可选参考，**不是取材约束**（「非科班自学 AI」是叙事人设，不限制选材范围）。
        复用他人示例 / 数字必须注明来源；**禁止零交叉的单源复述**。
        ▸ 检索工具（2026-10-18 定）：首选小红书 MCP `search_feeds`（站内同类笔记 +
          真实互动数，同平台对标）；公网证据补充 `python tools\research\fetch_sources.py`
          （Sogou/360 + arXiv，纯 stdlib 零依赖）。二者**仅服务 facts.md 信源层**，
          **不得当选题来源**（选题归 §8 cheat 链路）。
        【教学设计（2026-10-18 新增，治"内容烂"）】facts.md 必须含「## 四、教学设计」段，
        6 个子项缺一不可（这是 facts 从"事实台账"升级为"教学脚本"的关键）：
          ① **教学目标**：观众看完能做什么（一句话，可执行）
          ② **观众前置假设**：默认他知道什么 / 不知道什么（术语要解释到哪一层）
          ③ **每个例子的完整上下文**：什么问题、候选从哪来、为什么是这几个
          ④ **体验翻译**：这个数字/机制变化，观众会"感觉到"什么
          ⑤ **结尾落点**：可执行建议 + 开头钩子的回收句
          ⑥ **论证链 / 叙事弧**（2026-10-19 新增）：先用一句话锁死全片的论证顺序
             （例：它靠什么动 → 它怎么看 → 所以它在哪儿翻车 → 那该不该用它 →
             现实里大家怎么用 → 给你的建议），并逐章说明**本章承接上一章的哪个问题**
        该段由 pre-script 闸门校验（check.ps1 C7）。**2026-10-19 调整**：C7 由
        FAIL 降级为 WARN —— 内容质量改用 skill 自带质检机制（SCRIPT-STYLE 三层
        自检 + CHAPTER-CRAFT 完工自检）为主，机械断言仅作提醒，不再硬拦（避免
        用硬编码规则去"约束"文案质量）。
        【实证清单（2026-10-18 新增，人设红线）】script 若出现第一人称经历表述
        （我踩过 / 我实测 / 我做过 / 我试过 / 我跑通 / 我自己…），facts.md 必须含
        「## 五、实证清单」段，逐条列出该表述对应的真实记录（日期 / 文件 / 来源）；
        无实证即不得写（红线：不得编造个人经历与实测数据）。由 pre-code / delivery
        闸门强制校验（check.ps1 C8），命中且无实证即 FAIL。
        gh-daily 线豁免（fetch.py 选题卡即调研层，禁止重复造）。
   ▼ 【闸门 check.ps1 -Gate pre-script】验 facts 已定稿（含信源/数据段、无占位符）
Phase 1 内容：facts.md + 原始文章 → AI 产出 script.md(口播稿) + outline.md(章节/步骤
        + 分镜要素：每步标注 转场方式 / 视觉焦点移动 / 阅读保护时长) + beats.json(节拍表)
        【文案质检（2026-10-19 新增，治"文案不行"）】写 script 前**必须先读**
        `skills\web-video-presentation\references\SCRIPT-STYLE.md`（这是 skill 自带
        的口播稿规范，**不引入外部 skill**），按其 **四层自检**（形式层 8 原则 /
        风骨层·去 AI 味五类 / 念出来测试 / 结构层·分类树·衔接）逐项走完 → 按 fail 项改稿 → 落盘
        `script-selfcheck.md` 存证（逐条 pass/fail + 证据 + 改了什么）。
        **没有 script-selfcheck.md 不得进入 Phase 2**（pre-code 闸门校验）。
        【开场三要素（2026-10-31 新增，治"开头没背景 / 不听懂"）】SCRIPT-STYLE 第四层
        第 7 条已升级为三要素：**谁**（主体名词，不能只有"它"）/ **什么事**（题目）/
        **为什么值得看**（跟观众的关系）。前 2 拍任何一项缺席 = 悬空开场。
        selfcheck 里必须留下三项逐项 PASS/MISSING + 盲读第 5 项原文，C10 会校验，
        缺任一项直接 FAIL（ep11 连续四版都栽在开场，见 `docs/LESSONS.md`）。
        **执行者**：由执行本次任务的 agent 亲自审（陌生观众视角），不设人工中断点、
        不外包给人；审完即改稿，改完再审，直到三项全 PASS 才进 Phase 2。
        ▸ outline 每个 step 必须带 `元素:` 字段（见 §3.11）：从 viz 元素库挑
          与当拍口播相关的具象元素，**≥1 个/步**，写不出就说明这步画面会空。
   ▼ 【闸门 check.ps1 -Gate pre-code】验 facts+script+outline 三要素与步数一致
         + script-selfcheck.md 含开场三要素判定与盲读记录（C10）
         + 时长估算落在 120–180s（C14，仅 WARN）
         + backlog/.cheat-state 可解析（C15，FAIL）
   ▼ 【检查点 1·硬节点】一次对齐 6 件事：调研卡 / 稿子 / 大纲 / 主题 / 素材 / 开发模式
Phase 2 开发：脚手架建项目 → 读 CHAPTER-CRAFT.md（每章必读）→ 第 1 章完整做完
        【画面密度（2026-10-19 新增，治"画面空洞 / 内容只占屏 1/3"）】根节点用
        `.stage-3band`（顶部钩子行 / 中部主视觉 / 底部注释行），中部主视觉占舞台高
        **≥55%**；每个 step 至少挂 1 个 `templates/src/components/viz/` 的具象元素
        （11 个纯 SVG：浏览器窗/终端/文件夹/文档堆/对话气泡/卡片网格/流程管道/
        时间轴/数据条/循环箭头/检索放大镜）。整章只有"标题 + 一段文字" = 验收不过。
   ▼ 【检查点 2·硬节点】人工验收第 1 章（视觉/节奏/AI 味）
   ▼ 第 2~N 章（逐章确认 / 顺序开发 / subagent 并行）
   ▼ 【检查点 3·硬节点】是否合成音频
Phase 3 音频：extract-narrations → TTS（Kokoro 离线，见 4.x）批量合成 → public/audio/
   ▼ 【闸门 check.ps1 -Gate pre-render】验 数量守恒(C4) + 音频存在非空(C6)
Phase 4 录屏：?auto=1 一镜到底（首次按一次 Space 启动）→ record.mjs 落 marks.json(master timeline)
   ▼ 【闸门 check.ps1 -Gate delivery】全部断言 + master timeline 覆盖/帧数(C5)；WARN 升 FAIL
   ▼ 【抽帧目检 shots-review.ps1（2026-10-18 新增，人工）】按 marks.json 逐拍抽帧 → 生成
        目检清单，核对机器查不出的语义问题（图表数值一致 / 每拍信息量 / 例子来源标注 /
        钩子回收与衔接 / 留白节奏）。详见 3.10。
   ▼ 【闸门 validate.ps1】发布合规（发布前，见第 4 节）
```

四份"外部记忆"文件：`facts.md`(事实与比喻，常规/CS188 线必备) / `article.md`(素材) / `script.md`(节奏) / `outline.md`(章节切分+分镜要素)。
唯一真相源：每章 `narrations.ts`（数组长 = step 数 = 音频文件数）；改 step 数要 bump `useStepper.ts` 的 `STORAGE_KEY`，否则游标错位。

### 3.2 小红书竖版（3:4）关键改动
skill 原生只支持 16:9，**本项目已本地改造支持 3:4**（改动落在 `skills/web-video-presentation`）：
- 新增 `templates/src/stage.config.ts`（STAGE_W/STAGE_H 唯一真相源）
- `scaffold.sh` 加 `--ratio=3:4`（→ 1080×1440）/`9:16`（→ 1080×1920）/ 任意 `W:H`
- 生成项目：`bash scaffold.sh ./presentation --ratio=3:4` → `src/stage.config.ts` 即为 1080×1440
- 录屏视口设成 1080×1440；逐章留意超宽滑块、压缩段落间距等竖屏适配点

> ⚠️ 竖版改动尚未合回上游（见第 6 节 PR 待办）。

### 3.3 出片流水线（tools/record，本项目自写）
skill 文档规定用 OBS/DaVinci 拼多段音频；本项目用 Playwright 录屏 + Python 拼接器替代：
```bash
# 1) 录屏（VARIANT=vertical 用竖版项目）
node tools/record/record.mjs           # 按 ?auto=1 录 79 步（全步进）
# 2) 拼音频 + 合成 mp4
VARIANT=vertical python tools/record/build_master.py
# 3) 音画同步校验
python tools/record/verify_sync.py
```
- 本地验证版：`personal-agent-vertical.mkv`（48k 无损 PCM，拖条/变速零爆音）
- 上传版：`personal-agent-vertical.mp4`（48k AAC，平台二次转码源头干净）
- **阅读保护时间**：auto 推进 = 音频播完 + 停留供观众消化。模板默认 1500ms（舞台剧流水线"读后留 1.5s"标准，2026-10-17 起）；整片可调：录屏前设 `TRAIL_MS=800`（透传为页面 `?trail=`）；单步要更长保护 → 拆 step / 加长口播，不改代码
- 对轨不受 trail 改动影响：`build_master.py` 用 marks.json 实测的每步切换时刻摆音频，非时长累加
- 已修爆音根因：`build_master.py` 拼接 79 段时 `int(秒×字节率)` 算出**奇数字节偏移**，
  样本被字节交换成高频乱码（72 万处脉冲）。修法：偏移对齐到样本 `int(秒×采样率)×2`（必偶）。

### 3.4 环境约定（踩坑重灾区）
- bash 用 **Git Bash**（Git for Windows 自带；勿用 WSL，慢且环境错）
- node/npm 用 Windows 原生版本（勿在 WSL 里跑）
- TTS 用免费 **edge-tts**（不装 MiniMax mmx）；音色 `zh-CN-YunxiNeural`(男) / `XiaoxiaoNeural`(女)
- 主题推荐（技术类）：`blueprint` / `chalk-garden` / `terminal-green` / `forest-ink`

### 3.5 封面策略（**2026-10-27 起不设封面**）

> **决策**：本号从 2026-10-27 起**不再单独设置封面**，平台取视频首帧作为封面。
> **连带影响**：① 封面设计前移到**首帧**——第一拍必须自带大标题 + 钩子（等同原封面职责），因为它就是信息流里唯一的图像；② `validate.ps1 -CoverPath` 改为可选，不传即跳过封面尺寸检查并打 `[GATE-WARN]`；③ retro 不再因"封面未设"降权；④ `tools\cover` 与 `atutun-xhs-cover` 流程**停用**（代码保留，不再纳入交付清单）。

以下为停用前的封面流程记录（保留作回滚参考，默认不执行；若将来恢复封面，按此执行）：用 `skills\atutun-xhs-cover\` 生成本视频的小红书爆款封面提示词（阿囤囤风格：真人出镜+超大浅黄 #FDFFA7 标题+粗黑描边+emoji 贴纸）。2026-10-11 ep02 已实测 CLI 无人值守调用可用（先读 skill 本体→按规程直出，不提问不越界）。
- 产物：一段可直接喂图片生成模型的封面提示词（目标尺寸 1080×1440 竖版），主方案+备选方案各一份
- 该 skill 原生为**交互式**（逐一问 8 种风格选择题）；无人值守调用时 CLI 自行跳过提问，按内容选最贴合风格（默认风格 1 大字压顶 / 风格 4 教程清单）直出
- **成品图渲染（通用工具，所有视频线共用）**：提示词出完后跑 `python tools\cover\cover.py --title "<主标题>" --subtitle "<副标题>" --person <人物素材图> --style <1|4> --out <封面.png>`（阿囤囤规范 HTML/CSS → Playwright 无头截图，严格 1080×1440；中文大字不走文生图防错字；人物图只做圆形裁切+描边，禁止生成/重绘人脸）。用法详见 `tools\cover\README.md`
- **贴纸文案防残留（ep03 教训，2026-10-12）**：文字卡片贴纸必须显式传 `--sticker-label`（配 `--sticker-sub`）才渲染，**不传即无卡片**；禁止沿用上一期文案（ep03 曾残留 ep02 的「技能包·开源·免费」被发布）。背景代码纹理已固定为主题中立装饰。无真人素材时用 `--no-person`，版式自动垂直居中不留白
- **交付自述（强制）**：交付说明必须列出封面元素清单——标题/副标题/贴纸文案（或"无卡片"）/人物素材来源（或 no-person），供主控发布前目视核对语义正确性（validate.ps1 只查尺寸，查不出内容错）
- 人物素材：账号主理人真人参考照，或内容涉及具体人物时用其公开头像（如 GitHub 头像，须在 `--caption` 注明来源、不构成背书）
- 封面支线只依赖文稿定稿（标题/副标题），**可与主线出片并行**；成品 PNG 随发布包一起交付，发布前人工确认。MCP 无"改已发笔记封面"工具，封面必须在发布前就绪
- 8 种风格速查：1 大字压顶 / 2 巨字拆分 / 3 小白科普问答 / 4 教程清单 / 5 产品测评榜单 / 6 种草推荐 / 7 贴纸拼贴入门 / 8（详见 SKILL.md）

### 3.6 Skill 日报线：项目树章节（硬要求）
凡推荐某个 GitHub skill/仓库的视频（Skill 日报连载），**素材必须全走 `gh-daily\` 工具链**（先读 `gh-daily\PLAN.md` 作战方案；fetch.py 生成选题卡 → shot.py 页面截图 → 配色用 PLAN.md 2.2 实测值），禁止从 README 现拉数据重造。**且必须包含一章"项目结构树"**：
- 数据源：`gh-daily\candidates\<owner>__<repo>.json` 选题卡的 `top_paths` 字段（fetch.py 已抓好的真实路径清单，306~400 项）；无选题卡时先跑 `python gh-daily\fetch.py` 生成
- 呈现：目录逐行高亮/滚动展示，配一句口播点出关键目录（如 `skills/`、`commands/`、安装脚本位置）
- 参考：`gh-daily\public-crop-gh-tree.png` 是现成的 GitHub 文件树截图风格；PLAN.md 3.3 分镜表"5-20s 结构树滚动"即此章
- 目的：给观众"这仓库到底有什么"的实感，强化信息密度与收藏价值

### 3.7 口播节拍表（毫秒级，硬输入）
借鉴舞台剧流水线"工序二·竹子文案与口播节拍排布"。**口播稿定稿后必须产出节拍表，作为分镜与渲染对轨的唯一时间基准**。
- **节拍 = 一 step = 一聚焦想法**：`script.md` 里用 `---` 分隔，每段一拍；拍数 = 该片总 step 数
- 产出物 `beats.json`，字段固定：`step_id` / `chapter` / `step` / `start_ms` / `dur_ms` / `text`（ms 单位；`step_id` 形如 `hook:1`）
- **master timeline（唯一时间基准）= `marks.json`**：由 `record.mjs` 在录屏回放时落盘（`raw\marks.json`），schema `{t0, start, marks:[{id, t}], total}`，`id` = `<chapter>:<step>`。它是整片**音画对轨的唯一真相源**——正放/倒放/变速重放都对齐同一组实测切换时刻；章节代码与对轨逻辑**一律读它、不得硬编码毫秒**，也**不得用时长累加**代替。`beats.json` 是它的"排布计划版"（估时或 TTS 预排），出片后 `marks.json` 一落盘即以实测值为准
- **时长来源优先级**：① TTS 实测——`npm run extract-narrations` 得 `audio-segments.json`，录屏后 `record.mjs` 落 `marks.json`；② 无音频时的估时按中文 ≈ 4.5 字/秒，**必须标注「估时」**，不得冒充实测
- **硬约束**：分镜与章节代码**不得硬编码毫秒/秒数**（除 `(~Ts)` 口播估时）；对轨一律读 `marks.json` 实测值，不做时长累加
- **自检**：`beats.json` 拍数 == `narrations.ts` 数组长度 == 音频文件数（唯一真相源见 3.1）；覆盖率核对由 `tools\pipeline\check.ps1` 的 C5 断言完成（见 3.9）

### 3.8 视觉风格可切换（仅换提示词，代码骨架不动）
借鉴舞台剧流水线"固定时间轴与动作骨架，仅改提示词切风格"。
- **固定不动**：时间轴、每步动作骨架、step 划分、章节结构、对轨逻辑（`marks.json`）
- **本项目已锁定（2026-10-18 用户选定）**：账号统一主题 = `warm-keynote`（暖米底 `#f5efe1` / 墨棕字 `#43302b` / teal 强调 `#14b8a6`）；新片脚手架走 `scaffold.sh --theme=warm-keynote`，整号视觉统一（主页 banner 已同步暖调，见 `account.md` §6）
- **可替换（换风格只改这一层）**：① `src/styles/tokens.css` 主题 token（配色/字体/动效基线），`scaffold.sh --theme=<id>` 选主题或后期覆盖此单文件即整片换皮（23 内置主题见 `references/THEMES.md`）；② 章节提示词/视觉意象，决定"画什么"，不改结构
- **落地**：同一份 `script.md` + `outline.md` 可喂不同主题/提示词，产出剪纸风 / 工程蓝图 / 2.5D 微缩 / 复古像素等观感，而口播与时间轴保持一致
- **禁令**：换风格不得改 step 数（改了须 bump `useStepper.ts` 的 STORAGE_KEY，见 3.1）；不得为风格牺牲音画同步
- 参考：主题速查见 `VIDEO-GUIDE.md` §7、`skills\web-video-presentation\references\THEMES.md`

### 3.9 五工序契约闸门（check.ps1，2026-10-18 新增）
五工序流水线（facts→script/outline→章节代码→渲染→交付）**每道边界都机械校验"上道是否已定稿/完整"**，防「未定稿就动笔」与「带病交付」。工具 `tools\pipeline\check.ps1` 与 `tools\gate\validate.ps1` **分工**：本脚本管**工序契约**（开工前/交付前的内部一致性），validate 管**发布合规**（对外发布闸门）。

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 `
    -ProjectDir videos\<episode> -Gate delivery      # 出片后交付前，最严
```
| `-Gate` | 时机 | 校验范围 |
|---|---|---|
| `pre-script` | 写 script 前 | 只验 facts 定稿（C1） |
| `pre-code` | 写章节代码前 | facts + script + outline（C1~C3：三要素 / 步数一致） |
| `pre-render` | 出片前 | 再加 数量守恒(C4) + 音频存在非空(C6) |
| `delivery` | 交付/发布前 | 全部 + 时间轴一致性(C5，master timeline 覆盖 + 帧数)，WARN 升 FAIL |
| `media` | gh-daily 线专用 | 只验媒体层：数量守恒(C4) + 时间轴(C5) + 音频(C6)，跳过文本三件套 |
| `all` | 随时 | 文件存在即验（默认） |

- **断言**：C1 facts 定稿（存在 + 含信源清单/关键数据段 + 无占位符）｜C2 script 定稿（拍数≥2 + 无占位符）｜C3 outline 三要素（转场/视觉焦点/保护）+ 章步数合 == script 拍数｜C4 数量守恒（narrations == audio-segments == mp3 == beats == script 拍数）｜C5 master timeline（beats schema + `marks.json` 覆盖全步 + `raw\shots` 帧数）｜C6 音频存在非空（>2048 bytes）｜**C7 内容可用性**（facts 教学设计段 6 子项 + 结尾动作句 + 首拍钩子末 3 拍回收 + 术语首现解释）—— **2026-10-19 起降级为 WARN**，不再硬拦（内容质量改由 skill 自带质检机制把关）｜**C8 人设红线**（script 第一人称经历表述须有 facts「实证清单」实证）｜**C9 画面元素**（章节 tsx 是否用 `components/viz` 具象元素，WARN）｜**C10 文案自检存证**（`script-selfcheck.md` 存在，pre-code / delivery 门 FAIL）
- **退出码**：0 = 全绿（WARN 不阻断）；1 = 有 FAIL；2 = 参数/环境错误
- **开关**：`-SkipFacts`（gh-daily 线豁免调研卡时用）｜`-Determinism`（改进 B·确定性校验：首跑写基准 `raw\shots.sha256`，再渲一次复跑即比对帧哈希，不一致即判「存在抽卡」）
- **接入点**：心跳目标段开工前后各跑一次对应门；人工派活也在**交付前**跑 `-Gate delivery`。判定依据为 backlog goal 的 `line` 字段
- **适用范围**：按**现行契约**（facts.md + `---` 分拍 + outline 三要素表 + beats.json，以 ep05 为基准）校验。`regular-ep03/ep04` 为契约确立前的**历史集**，FAIL 属预期、**不回溯修补**；`gh-skill-daily` 线根目录无文稿四件套，用 **`-Gate media`** 只对 `*-presentation\` 内的数量守恒/时间轴/音频做核对（实测 ep02：32 段音频守恒通过）

### 3.10 抽帧目检（shots-review.ps1，2026-10-18 新增）
check.ps1 是**文本级**闸门，读 md/json，**读不懂画面**——ep06 的「柱状图只渲染首柱 / 后半程四拍只有一张文字卡 / 图注未标例子来源」全部穿透它。故在**出片后、发布前**补一道人工目检：

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\shots-review.ps1 `
    -ProjectDir videos\<episode>
```

- 按 master timeline（`marks.json`）逐拍取**中段**抽帧，生成 `shots-review.md` 目检清单（逐拍含口播文本 + 帧路径 + 4 项勾选）；帧与清单默认写 `%TEMP%\shots-review\<ep>\`（临时区，不污染项目目录；`-OutDir` 可改）
- **核对 4 项**（机器查不出的语义层）：① 图表数值与标注是否一致（柱高对不对得上百分比）② 每拍信息量是否足够（防"标题 + 一张空卡"）③ 例子/数字的来源出处是否在图注或口播标注 ④ 钩子是否结尾回收、章节衔接是否成立 + 留白节奏
- Windows PATH 的 ffmpeg 在本机是**坏 shim**，脚本已自动回退 WSL ffmpeg（`wsl -e bash -lc`）
- **不阻断**（人工项），但目检发现的硬伤（图表画错 / 来源未标 / 钩子悬空）必须回修后才可进发布

> ⚠️ **工程约定**：`tools\pipeline\` 下的 .ps1 必须存为 **UTF-8 with BOM**。PowerShell 5 对无 BOM 文件按 GBK 解析，中文会乱码并触发语法错误（`shots-review.ps1` 首跑即踩坑）。

### 3.11 画面密度与具象元素库（visual-density，2026-10-19 新增）

治 ep07 的两条批评：**画面空洞（内容只占屏幕 1/3）** 与 **文案不行**。
前者在本节治，后者见 §3.1 的 SCRIPT-STYLE 四层自检。

**改动落点（全在 skill 模板层 → 新片自动继承；已发布内容不回溯，ep07 不重制）**：

| 层 | 文件 | 改了什么 |
|---|---|---|
| 舞台 | `templates/src/hooks/useStageScale.ts` | margin 默认 0 → 录制视口 == 舞台尺寸时 **scale = 1 满幅**，不再四周露米色壳（原 80/100px 留边让有效面积缩水到 ~85%） |
| 底纹 | `themes/warm-keynote/tokens.css` | 新增 `--surface-pattern-z: 3` → 暖色网格画在章节内容之上，消除"大块空色" |
| 版式 | `templates/src/styles/base.css` | 新增 `.stage-3band` / `.band-top` / `.band-main`（`minmax(55%,1fr)`）/ `.band-foot` / `.viz-fill` |
| 录屏契约 | `templates/src/styles/base.css` | `.scene *` 动画/过渡压到 110ms 且延迟归零 → 截图必为设计终态（原来 900ms 入场 + 650ms 错峰会被截成半成品） |
| 元素库 | `templates/src/components/viz/` | 11 个纯 SVG 具象元素 + `README.md` 选用手册 + `index.ts`（`scaffold.sh` 自动拷贝） |
| 规范 | `references/CHAPTER-CRAFT.md` / `OUTLINE-FORMAT.md` / `SKILL.md` | 新增「版式密度」硬指标 + 完工自检项 + outline 必填 `元素:` 字段 |

**元素清单（11）**：`BrowserWindow` `Terminal` `FolderTree` `DocStack` `ChatBubbles`
`CardGrid` `PipelineFlow` `TimelineRail` `BarChart` `LoopArrow` `Magnifier`。

**硬规则**：① 每 step ≥1 个、且与当拍口播相关（讲到检索挂放大镜，讲到流程挂管道）；
② 中部主视觉 ≥55% 舞台高、填满宽度、比"一眼看清"再放大 1.5~2×；
③ 元素一律 SVG + 主题 token，**禁** emoji / 位图 / 假数据（数字由调用方传真实值）；
④ 四周留白照旧，但**不放**页眉页脚与右下角固定角标。

**为什么不为文案另装外部 skill**：用户裁定复用 skill **自带**的 `SCRIPT-STYLE.md`
（四层自检）+ `CHAPTER-CRAFT.md`（完工自检），不引入第三方文案 skill。

---

## 4. 发布（xiaohongshu-mcp）

### 4.1 启动服务（每次开机一次）
```powershell
powershell -File <repo-root>\mcp\start-mcp.ps1   # 需自行安装 xiaohongshu-mcp 后使用
# 看到 "启动成功，HTTP 200" 即可；端口 18060
```

### 4.2 IDE（Trae）连接
设置 → MCP → 创建 → 手动配置：类型 `streamable HTTP`，URL `http://localhost:18060/mcp`。
连上后应有 18 个工具。

### 4.3 登录（失效时）
说"检查小红书登录状态，没登录就给二维码" → 扫码；或双击 `mcp\xiaohongshu-login.exe`。
登录态存 `cookies.json`，长期有效。

### 4.4 工具与硬约束
| 工具 | 说明 | 注意 |
|---|---|---|
| `publish_content` | 发图文 | title ≤ 20 字；正文不手写 `#`，话题标签走 `tags[]`（3~6 个领域标签，推流用）；图片传**绝对路径** |
| `publish_with_video` | 发视频 | **无「声明原创」入参**；**MCP 无删除笔记接口**（删旧笔记须 App 内手动） |
| `check_login_status` / `get_login_qrcode` | 登录态 / 二维码 | — |
| `get_my_profile` / `list_feeds` | 查自己笔记 / 信息流 | `list_feeds` 只返发现流，拿不到自己 note_id |

**人工闸门**：所有写操作（发布/删除需手动/评论）前必须用户确认；AI 不直接点发布。

### 4.5 发布后回读校验（强制 · 2026-10-25 事故后新增）

**事故**：2026-10-25 发布 exp10/exp11，两条笔记的标题与正文中文**全部变成 `?`**（平台原文即乱码）。根因是 PowerShell 5.1 把 UTF-8 的 JSON 字符串交给 `Invoke-WebRequest` 时按 ANSI 编码发送，服务端按 UTF-8 解码，汉字塌成 `U+003F`。发布接口仍返回"发布成功"，调用器只打印字节长度 → 两条乱码笔记上线约 3 小时才发现。

**强制动作（每次发布后、回写 log 前）**：

1. 用 `tools\publish\verify-note.py` 从平台**回读**刚才发的笔记，机械断言：标题非空且不含 `?`、标题与预期一致、正文中文 ≥ 20 字；
   ```
   python tools\publish\verify-note.py --note-id <note_id> --title "<note_id>=<预期标题>"
   ```
2. 退出码 **0** 才可在 `log.md` 登记为"已发布"；退出码 **1** = 编码损坏，**不得登记**，须由账号所有者在 App 内删除后重发（MCP 无删除接口）；
3. 回读时若 MCP 无阅读数据，只断言标题/正文，阅读数仍走人工截图。

**编码链路要求**：所有 MCP 调用的 JSON body 必须转成 UTF-8 字节再发送（`[System.Text.Encoding]::UTF8.GetBytes($json)`），禁止把字符串直接传给 `Invoke-WebRequest -Body`；Python 侧统一 `json.dumps(..., ensure_ascii=False).encode("utf-8")`。

### 4.6 数据抓取（2026-10-27 新增 · 替代人工截图）

**背景**：MCP 是预编译二进制，只给赞/藏/评，**没有**曝光、观看、点击率、2 秒退出率、人均观看时长、涨粉、逐日曲线。此前这些全靠账号所有者手动截图，已连续阻塞两次复盘。

**做法**：`tools\metrics\pull.js` 用 Playwright + 独立登录态直接读创作者中心。

- **首次 / 登录态失效**：`node tools\metrics\login.js` 会弹出浏览器，由**账号所有者扫码登录一次**；登录态存入 `tools\metrics\session.json`（已进 `.gitignore`，勿提交、勿外传）
- **日常抓取**：`node tools\metrics\pull.js`（或 `powershell -File tools\metrics\pull.ps1`）
- **产出**：`data\metrics\latest.json`（账号 7日/30日 + 全部笔记汇总）+ `data\metrics\history.jsonl`（每次追加，可做趋势）
- **字段**：单篇 `impressions / reads / ctr / likes / favorites / comments / shares / danmaku / fans_gained / avg_watch_s`；账号侧另有 `full_view_rate / fans_lost / net_fans / home_visitors / daily_impressions / daily_reads`

**四条硬约束**：

1. **主站 cookie（`mcp\cookies.json`）进不了创作者中心**——创作者中心是独立 CAS 登录，复用会 401/406。别试。
2. 平台接口有**签名校验**，裸 `fetch` 返回 **406**；只能"页面自己发请求 + 拦截响应"，不要把实现改成直接请求接口。
3. 单篇的 `exit_view2s_rate`（2 秒退出率）、`finish5s_rate`（5 秒完播）、`play60s_count` 在 `datacenter/note/base` 接口里，但该接口只由**单篇分析详情页**触发；`pull.js` 目前覆盖列表汇总，这 3 个字段仍需人工点开该笔记详情（接口已定位，后续可接入）。
4. 抓取频率 **≤2 次/天**，避免风控；数据滞后约 1 天，以 `data_last_update_time` 为准。

**工作流接入**：`snap-<id>-24h` / `retro-<id>` 回收时**优先读 `data/metrics/latest.json`**，不再要求人工截图；只有该文件缺字段（如需要 2 秒退出率）才请账号所有者补图。

**adapter 协议接入（2026-10-27）**：把 `pull.js` 包装成 xhs-explore 约定的 adapter，`data_collection=adapter` + `enabled_perf_adapters=["xhs-explore"]` 后 `/cheat-retro` 可直接调用。

- **入口（用固定路径，不要用 `find ~` 定位——本项目的 skill 装在项目内而非 home）**：
  `bash skills/cheat-on-content/adapters/perf-data/xhs-explore/run.sh <note_id> <video_folder> [script_path]`
  上游 `run.sh` 检测到 `tools/metrics/adapter/run.sh` 会直接 `exec` 委托，**不跑 Python crawler**（两套 cookie 体系并存会互相打架）
- **本地实现**：`tools\metrics\adapter\run.sh`（`latest.json` 在 30h 内直接复用，否则先跑 pull）+ `report.mjs`（渲染成上游同格式 `report.md`，含曝光/浏览/点击率/赞藏评/涨粉/人均观看 + 派生比率）
- **退出码（与上游一致）**：0 成功 / 1 登录态失效 / 2 依赖缺失 / 3 其他失败；`report.md` 未生成即非 0
- **前提**：`tools\metrics\session.json` 存在。上游的 `.auth-xhs/` 与本 adapter 无关，不需要装 `.venv` 或 Python playwright
- **字段缺口不变**：2 秒退出率 / 5 秒完播 / play60s 仍需人工补，`report.md` 末尾会明写

**判定口径（2026-10-27 起）**：曝光和观看都是**结果**。判断内容好坏只看两项——`ctr`（标题 + 首帧的吸引力，本号不设封面）与 `avg_watch_s` / `finish5s_rate`（内容留存），不看裸曝光量。

---

## 5. 视觉规范（图文 + 视频封面统一）

> ⚠️ **基线说明（2026-10-18）**：本节为建档期**图文线**视觉基线。所有作品已统一为视频形态，视频主题锁定 **`warm-keynote`**（见 3.8），主页 banner 已对齐暖调（见 `account.md` §6）；封面成品由 `tools\cover\cover.py`（阿囤囤风格）承担。克莱因蓝主色现仅存于历史图文脚本（`posts\...\gen_images*.py`），新交付不再使用。

- **主色**：克莱因蓝 `#2B5BFF`
- **底色 / 文字**：浅色底 `#F5F5F0` / 正文 `#1A1A1A` / 辅助灰 `#8A8A85`
- **尺寸**：图文 & 视频封面均 3:4 竖版 1080×1440
- **字体**：微软雅黑（粗 `msyhbd.ttc` / 常规 `msyh.ttc`）
- **版式**：浅色极简底 + 大号黑字标题 + 克莱因蓝高亮标签块；全站统一模板
- **账号昵称**：`<你的账号名>`
- **slogan**：`<一句话主张>`
- **bio**：`<你的简介>`

---

## 6. 已知待修 / 坑

1. **路径约定**：所有档案路径统一以仓库根为基准，脚本不要写死个人绝对路径。
2. **爆音已修**：`build_master.py` 1 字节错位 bug 已根治（见 3.3），重渲后成片 0 爆音。
3. **视频线 3:4 改动未合上游**：本地 3:4 变体以 patch 形式维护；上游更新后需重新应用。
4. **养号期前 7 天**：只发学习笔记线，不发引流；每天 ≤ 2 条，间隔 ≥ 2h（见 `account.md`）。
5. **旧爆音笔记已删**：旧笔记已在 App 内手动删除（MCP 无删除接口，此类操作只能在 App 完成）。

---

## 7. 快速检查清单（每次发布前）

- [ ] 已读 `account.md` + `log.md`
- [ ] 图文：标题 ≤ 20 字、正文无手写 `#`、tags[] 已填 3~6 个领域标签、配图 1080×1440 已生成
- [ ] 视频：facts.md 调研卡已定稿（常规/CS188 线必查；gh-daily 线豁免）、outline.md 含分镜要素（转场/焦点/保护时长）
- [ ] 视频：已跑 `tools\pipeline\check.ps1 -Gate delivery` 全绿（工序契约：数量守恒 / master timeline 覆盖 / 音频非空，见 3.9）
- [ ] 视频：竖版 `--ratio=3:4`、音画同步校验通过、无爆音（VLC 拖条/变速验证）
- [ ] 封面提示词已用 atutun-xhs-cover 生成，且成品封面图已由 `tools\cover\cover.py` 渲染（1080×1440 PNG，随发布包交付，见 3.5）
- [ ] MCP 服务已启动 + 登录态有效
- [ ] 无绝对化用语（最/第一/100%）、无变现动作；搬运适度并注明来源
- [ ] **发布动作已获用户确认**
- [ ] **发布后回读校验通过**：`python tools\publish\verify-note.py --note-id <id> --title "<id>=<标题>"` 退出码 0（查中文是否变 `?`，见 4.5）
- [ ] 发布后回写 `log.md`（note_id / 24h / 7d 数据）
- [ ] 已跑 cheat-predict（盲预测落盘后才许发布，见第 8 节）

---

## 8. cheat-on-content 校准循环（叠加层）

> skill 本体 `skills\cheat-on-content\`（顶层总路由 + 14 子 skill）。
> 方法论：打分 → 盲预测 → 发布 → T+3d 复盘 → 进化 rubric。它**不替代**第 2/3 节创作流程，
> 只在「文案完成 → 发布 → 数据回收」三个节点上插桩，把 log.md 的数据回填升级为可校准实验。

### 8.1 与主流程的衔接点

```
选题 ──▶ cheat-seed（一次性）/ cheat-recommend + cheat-trends（日常选题池）
         热源 adapter（2026-10-18 接线）：`aihot`（AI 垂类热源，已装 skills\aihot 并写入
         .cheat-state.json enabled_trend_sources，manual-paste 兜底）。注意 aihot 授权范围：
         个人非商业 / 公益 / 组织内部免费，**对外商业用途须先获 AIHOT 书面授权**（见其 LICENSE）
文案定稿 ──▶ 人工审核（原有闸门不变）──▶ cheat-predict（五维打分 + 盲预测落盘）★发布前硬节点；落盘时把「## 预测」段 sha256 记入 .cheat-state.json prediction_hashes（哈希锁）
MCP 发布 ──▶ cheat-publish（登记已发布，buffer -1）
T+24h/3d/7d 数据回收（心跳自动，见 9.1）──▶ log.md 回填 ──▶ cheat-retro（先验哈希锁，预测 vs 实际复盘，追加不可改）
积累 5+ 样本 ──▶ cheat-bump（全量重打 + 跨模型审核后升级 rubric）
```

**分层接入（2026-10-12 用户拍板）**：cheat 的接入深度按内容线别分两档——
- **起号专题**（skill 推荐 gh-daily 线、CS188 课程笔记线）：**部分跑**。选题层（seed/recommend/trends）跳过——选题由流水线/课程大纲外部定死；但 predict → publish → retro **主干必跑**，专题的使命就是攒"预测 vs 实绩"样本喂 bump 自进化
- **其他一切作品 + 账号运营方向**（`line: 常规`）：**全跑**，含选题层；CLI 自主用 recommend/trends 维护候选池、persona 分析、bump 评估，人不做逐条干预
- 判断依据：backlog goal 的 `line` 字段（`专题-skill日报` / `专题-cs188` / `常规`；缺省按常规全跑）。预测档案与 retro 均须带此标签，bump 时按线别分组评估，防形态不同的样本互相污染 rubric 权重
- 时序逻辑：专题是启动器（让循环转起来、攒够样本），账号基调跑起来后运营权逐步交给 skill 全循环

### 8.2 状态与记录分工

- cheat 状态文件（`.cheat-state.json`、预测/复盘档案）由 cheat-init 建在本项目根；**首次使用前先说"初始化 cheat-on-content"**
- `log.md` 仍是发布记录唯一真相源（note_id / 数据）；cheat 档案是它的"预测-偏差"延伸层，两边同一条笔记用 note_id 关联
- 图文与视频**两条线都插桩**（小红书曝光量可量化，满足方法论前提）

### 8.3 Trae 环境适配注意

- Claude Code 的 slash-command 与 `hooks/prediction-immutability.sh` 在本环境**不生效**：子 skill 按总路由表用自然语言触发；「预测段写完 immutable」靠人工遵守协议（见 `shared-references/blind-prediction-protocol.md`）
- 当前 rubric 为本号自建 **v1-retention（五维 HO/PE/TK/NA/QL）**，目标函数是人均观看秒数，不是曝光（2026-10-27 换轴，见 `RUBRIC.md` 头注与 `cache/bump-20261024-draft.md`）
- cold-start 期只要求五维打分 + 一句话 bet，不强求数字预测（避免 false precision）
- 建议尽快 `cheat-learn-from` 导入 2–3 个同类学习博主作为初始信号源
- **hooks 实测不可用**（2026-10-12 实测：WorkBuddy CLI v2.164.0 的 settings 无 hooks 配置域，PreToolUse/SessionStart 静默忽略）。替代方案全部落在规程层：immutability→哈希锁（见 8.1 与 9.1）、meta-logging→各节点主动追加 `.cheat-cache/usage.jsonl`、session-start→CODEBUDDY.md 必读清单

### 8.4 cheat → 创作：三段回路（2026-10-27 新增）

> 目的：让 cheat 不只在"文案定稿后打分 / 发完复盘"两个点插桩，而是**从选题开始就影响内容本身**。
> **原则：不填表、不套模板。** rubric 是问题清单，不是评分卡；钩子怎么开、结构怎么排、例子选哪个，由 CLI 按本篇内容自己决定，rubric 只给约束（见 `RUBRIC.md` 硬约束段）。

| 节点 | 动作 | 产物 |
|---|---|---|
| **创作前**（写 script 之前） | 读 `RUBRIC.md` 当前公式 + `data/metrics/latest.json` + `LESSONS.md` + 最近一篇 retro；回答三问 | `videos\<episode>\design-intent.md`（自由文本 ≥1 段，不写表格） |
| **创作中**（script 定稿后） | 按五维自评，每维给分数 + 稿内原句作证据；任一维 ≤2 必须改或写明保留理由。**追加「一句话复述」：只读稿子，用一句话回答"谁中招 / 发生了什么 / 我该干嘛"，三问缺一即改稿**（2026-10-30 ep10 教训：五维 9.29 但用户完全听不懂） | 追加 `## cheat 视线` 段到 `script-selfcheck.md` |
| **创作后**（retro） | 判"哪一维预测准 / 哪一维错"，压成一行 + 一条下篇动作 | `LESSONS.md` 追加一行；证据仍写 `rubric-memo.md` |

三问（必须带本篇的具体数字和具体稿子，写不出来就停下问人）：
1. 这篇要动哪个指标，目标数字多少（从 `latest.json` 的分布里取，不许许愿）
2. 参照自己哪一篇历史笔记，为什么可参照（同形态 / 同时长 / 同受众），它做对了什么
3. 这次规避 `LESSONS.md` 里的哪一条，本篇的具体动作是什么

衔接规则：
- `design-intent.md` 的"目标指标 + 数字"必须与 `cheat-predict` 落盘的中枢一致；不一致时以 design-intent 为准，并在预测档案注明原因
- 自评分**不替代** blind 子 agent 的打分；两者差 ≥2 分时，在预测档案写明差在哪
- retro 的教训行只写可执行动作，不写"这次数据不好"这类结论
- 这三步是**判断**，不是交付物：不许编数字、不许复制上一篇的 design-intent
- `check.ps1` 的 C13 只在 pre-script 门对 `design-intent.md` 缺失 / 过短发 **WARN**，不阻断（内容质量不用硬编码规则约束）

---

## 9. 自主运营架构（心跳 + backlog + 闸门）

> 目标态：人退到审计位，CLI 由定时心跳自主拉活。三项改进（①数据回收 ②自主心跳 ③SOP 进化）按 2026-10-12 用户拍板实施。

### 9.1 数据回收节点（传感器闭环，改进①）

- **数据源（2026-10-27 起以 §4.6 为主）**：
  - `data\metrics\latest.json`（`node tools\metrics\pull.js`，Playwright 读创作者中心）：曝光 / 观看 / 点击率 / 赞 / 藏 / 评 / 涨粉 / **人均观看秒数** / 账号 7·30 日汇总 + 逐日曲线
  - xiaohongshu MCP **只读工具**补事件流：`get_my_profile`（粉丝/获赞总数、xsecToken）、`get_feed_detail`（单篇赞藏评）、`list_notifications`（喂 persona）
  - 仍缺的只有单篇 `exit_view2s_rate / finish5s_rate / play60s_count`（需人工点开该笔记详情页截图；接口已定位，后续可接入）
- **快照节奏**：每篇发布后 **T+24h / T+3d**（与 rubric 的 T+3d 复盘窗口对齐）；T+7d 只在需要观察长尾时补，非默认
- **定点取不到时（后台聚合滞后约 1 天）**：用该窗口内最接近的实际时点值，并在条目 `notes` 写明 `basis`（例：`actual T+26h10m`）。**跨时点值不得用来比较速率**（exp10/11 曾因此让 A/B 对照失效）
- **抓取频率 ≤2 次/天**：维护段每天跑 1 次即够，不额外加抓
- 回收前先 `check_login_status`；若 `latest.json` 缺失或 `pulled_at` 超过 30h，维护段先跑一次 pull。登录态失效 → 该 goal 置 blocked 并告警，**绝不自动重登**
- 回收后回写 `log.md` 对应字段 + 追加 `.cheat-cache/usage.jsonl` 一行 `{"event":"perf_snapshot",...}`

### 9.2 心跳与 backlog（自主主环，改进②）

- **载体**：Trae 侧 Schedule 定时任务，每天 **20:30** 一次（2026-10-27 由 10:30 调整）；同日双 goal 时由 Trae 手动加排（不做自动加班逻辑）
- **唤醒动作（2026-10-27 改造）**：跑 `tools\pipeline\heartbeat.ps1` —— 由 Schedule 在前台（沙箱外）用 WMI 派生：`([wmiclass]'Win32_Process').Create('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "<repo-root>\tools\pipeline\heartbeat.ps1"')`。选 WMI 而非 `Start-Process`：派生进程挂在 WmiPrvSE 下，不随 Trae 会话的进程树被回收。脚本内部完成 PATH 补全 / 模型解析 / `CODEBUDDY_CONFIG_DIR` 注入 / 简报「执行心跳」，并把 CLI 的 stdout+stderr 合并写入 `cache\heartbeat\YYYYMMDD-HHMMSS.log`（start 行 + `exit=` 行）
  - **不要用 `run_in_background=true` 直接拉 `codebuddy`**：该模式下沙箱放行不生效，CLI 启动即崩（`EPERM` → 退出码 `0xC0000409`，2026-10-27 实测）；失败表现为日志停在 `First raw chunk received`
  - **核验方式**：看最新日志是否有 `heartbeat end ... exit=0`，再看 backlog 是否按预期变更；只有 start 行、无 end 行 = 被中断，不得当作已执行
  - 模型由启动器按 `-Stage writing` 解析后显式传入；goal 自带 `"model"` 字段时，CLI 在会话内仍以此为准
- **模型路由（2026-10-17 新增，零充值原则）**：模型由**拉起方**（Trae/人）在命令上指定（`codebuddy -p -y --model <id>`），CLI 会话内不自切换。按工序选档，免费优先、质量不够才升低成本档：
  | 工序 | 首选 | 积分倍率 |
  |---|---|---|
  | 最不会出错、不占磁盘的轻任务（维护段：登录态检查 / 到期快照回收 / retro 到期检查 / bump 计数；backlog 状态流转；发布登记；账本与文档纯文本改写）——**判据：只读检查或纯文本改写，不产出成片·音频·封面等占盘产物** | `hy3` / `hy4-preview-f` / `step-5-preview`（免费池，switch-free-model.ps1 探测顺序） | x0.00 |
  | **上表描述未覆盖的其他任务**（非视觉类：文稿 / 口播稿 / 预测档案 / 复盘 / 其余机械步骤等） | `deepseek-v4.1-flash`（实测最好用的通用模型） | x0.11 |
  | 章节视觉代码 / 图形 / 封面相关 | `glm-5.3-flash`（实测图形视频类好用、最便宜的可用档） | x0.06 |
  goal 条目可带 `"model"` 字段覆盖默认路由；goal 无该字段时按上表工序→档位选。
  - **解析脚本（2026-10-17 改造）**：`switch-free-model.ps1 -Stage mechanical|writing|vision [-ResolveOnly]`——按上表给出候选链（工序首选 + 免费池兜底）并逐档探测可用性（非 429）。加 `-ResolveOnly` 只打印 `MODEL=<id>` 供拉起方拼 `--model`，不改 CLI 默认；不加则把 CLI 默认模型切到解析结果。无 `-Stage` 时保持旧行为（当前模型能用就保留，否则扫免费池）
- **熔断**：backlog.json 顶层 `"halt": true` → 心跳直接跳过不烧 token；连续 2 次会话异常退出由 Trae 置 halt
- **单次会话两层颗粒度**（goal 边界 = 审计边界）：
  1. 维护段（必跑、幂等、分钟级）：登录检查 → 到期快照回收 → retro 到期检查 → bump 计数
  2. 目标段（**至多 1 个 goal**）：按优先级 待发布 > 生产 > 选题 取一个执行；发布类 goal 必须先过 validator 闸门
- **backlog.json 权限模型**：
  - 人/Trae 独占写入：`type:"goal"` 新条目（内容目标）、`halt` 开关、`publish` 字段值、`model` 字段值（见上模型路由）
  - CLI 可写：status 流转（pending→in_progress→done/blocked/awaiting_publish）、到期派生的维护类条目（retro/snapshot/bump_check）、usage.jsonl
  - CLI **不可**：新增内容 goal、改 publish 授权、删条目
- **发布授权颗粒度**：goal 条目带 `"publish": "confirm"|"auto"`。**起步阶段一律 confirm**（跑到发布闸门即停、置 awaiting_publish 等人说"发"）；连续 5 篇全流程零异常后，由用户再议 auto（全面放手）
- **goal 线别字段**：goal 条目带 `"line": "专题-skill日报"|"专题-cs188"|"常规"`，决定 cheat 接入深度（见 8.1 分层接入；缺省按常规全跑）
- **goal 目录字段（2026-10-27 新增）**：goal 条目带 `"project_dir": "videos\<episode>"`，作为 `check.ps1 -ProjectDir`、`design-intent.md`、`script-selfcheck.md` 的唯一定位来源；**缺该字段时 CLI 不得猜目录**，按 blocked 交回。历史 goal（ep03 / ep04 / ep09 / exp 系列）无此字段，不回溯
- **发布时间字段口径（2026-10-27）**：`.cheat-state.json` 的 `last_published_at` **只记常规线**；实验线另记 `last_publish_any_at`（当前为 exp11 的 10-26T18:24）。validator 的"当日篇数 / 间隔 2h"仍以 `log.md` 实际发布记录为准，不读 state
- **validator 闸门**（`tools\gate\validate.ps1`，发布前强制，任一不过即禁发+告警）：当日发布数 ≤2、距上篇 ≥2h、标题 ≤20 字、tags 3~6 个、预测档案存在且「## 预测」段哈希锁匹配、**封面可选**（传 `-CoverPath` 才校验 1080×1440；不设封面时省略并打 GATE-WARN）、成片存在、**音频硬校验**（仅视频笔记：真响度 `loudnorm` I ∈ −30..−14 LUFS 且真峰值 ≤ −1.0 dBTP；**禁用 `volumedetect` 均值**——它把静音一起算进均值，含停顿的口播会被误判越界；I < −20 只告警不阻断）

### 9.3 SOP 进化（playbook 提案，改进③）

- CLI 在 retro 或生产中踩坑后，向 `playbook_proposals.md` **追加**提案（固定四段：问题/证据/建议改动/影响文件），只追加不修改不删除
- 合入权在人+Trae：定期审提案，择优改 WORKFLOW/CODEBUDDY，审后在提案行标记 合入/驳回
- 禁区：护栏文件（CODEBUDDY.md/WORKFLOW.md/account.md/log.md 红线段）、RUBRIC.md 正式 bump 均不可由 CLI 直接改；本环境 bump 的"跨模型独立审核"降级为 Trae 审，档案如实标注

### 9.4 上线状态与验收

- [x] 9.1 数据回收规程 + 哈希锁（2026-10-12 固化）
- [x] 9.2 backlog.json + validator + CODEBUDDY.md 护栏改写 + Schedule 心跳（2026-10-12 上线）
- [x] 9.3 playbook_proposals.md 建档
- [x] 首次心跳实跑（2026-10-13 10:48 回收完成，维护段幂等、无越界写）
- [x] 首次自动数据回收（2026-10-13 补收 ep01/ep02 基线 + ep02 24h 点）
- [x] 首次 retro 实跑（2026-10-14 ep01，含哈希锁校验）
- [x] 自动化数据源接入（2026-10-27：`tools/metrics` 取代人工截图，见 §4.6 / §9.1）
- [x] rubric 换轴 v1-retention（2026-10-27，校准池归零）
- [ ] 5 篇零异常 → 用户议 auto（当前 0/5，v1 重新起算）
