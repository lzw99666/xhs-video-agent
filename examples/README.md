# 示例导览

这里是一条**真实发布过的**小红书视频《同一个问题，AI 为什么每次答得不一样》的全部文本资产（`ep11-sampling/`），以及从成片里抽的 5 张帧（`shots/`）。

它存在的目的不是让你抄文案，而是让你看清**每一步应该产出什么、检查什么**。

---

## 一眼看懂：文件在流水线里的位置

```
article.md ──▶ facts.md ──▶ script.md ──▶ outline.md ──▶ beats.json
                   │            │             │
                   │            └──▶ script-selfcheck.md（闸门存证）
                   └──▶ design-intent.md（创作前三问）

                   以上全部通过 check.ps1 -Gate pre-code 后才进入网页开发
```

| 文件 | 阶段 | 它回答什么问题 | 模仿时看什么 |
|---|---|---|---|
| [`article.md`](ep11-sampling/article.md) | Phase 0 输入 | 原始素材讲了什么 | 素材长度和信息密度；这是"原料"，不是"成稿" |
| [`facts.md`](ep11-sampling/facts.md) | Phase 0 产物 | 哪些事实可以讲、出处是哪、怎么讲才不误导 | **信源清单的交叉关系**、口径边界、教学设计 6 项、论证链 |
| [`design-intent.md`](ep11-sampling/design-intent.md) | 创作前 | 这条想动哪个指标、参照谁、规避哪条教训 | 三问是否带**本篇的具体数字**，而不是口号 |
| [`script.md`](ep11-sampling/script.md) | Phase 1 | 观众听到的每一句话 | `---` 分拍 = 一屏 = 一段音频；段落形态，不是字幕形态 |
| [`outline.md`](ep11-sampling/outline.md) | Phase 1 | 每一拍屏幕上出现什么 | 每步的 `元素:`、转场、视觉焦点、阅读保护时长 |
| [`script-selfcheck.md`](ep11-sampling/script-selfcheck.md) | Phase 1 闸门 | 稿子过没过自检 | 四层自检逐项 pass/fail + 证据；开场三要素；盲读原文 |
| [`beats.json`](ep11-sampling/beats.json) | Phase 1 产物 | 每拍的毫秒级排布计划 | 注意 `dur_ms` 是**估算**，出片后以 `raw-vertical/marks.json` 为准 |

---

## 这套示例的三个"可迁移"点

### 1. 信源要交叉，而且写清边界

`facts.md` 里每个关键结论至少两个独立来源，并且明确写了"哪些话不能说"：

- 各家温度量程不同（0–2 / 0–1），所以口播只说"低 / 高 / 0"，不报具体量程
- 1000 次出 80 个结果是**别人在自家推理栈上做的实验**，不能说成"所有模型都这样"

这是"不误导"的具体做法，比任何"请注意准确性"的嘱咐都有效。

### 2. 大纲的每一步都有画面元素

`outline.md` 里每个 step 都有 `元素:` 字段，从 skill 的 viz 元素库挑一个具象元素（对话气泡 / 环形箭头 / 数据条 / 时间轴……）。**写不出元素的步骤，说明这屏会是空的**，应该在写大纲时就改掉，而不是等到开发阶段才发现。

### 3. 自检要留证据，不是打勾

`script-selfcheck.md` 的每一行都是"判定 + 证据 + 改了什么"，例如"开场三要素：谁 PASS / 什么事 PASS / 为什么值得看 MISSING → 第 2 拍补了一句和你有什么关系"。没有证据的 PASS 等于没检。

---

## 截图对应的时间点

| 文件 | 成片时间 | 画面 |
|---|---|---|
| `shots/01-hook.png` | 0.6s | 同一句提问，三个不同的回答，第三条结论反了 |
| `shots/02-sampling.png` | 12s | 环形箭头 + "掷骰子"，给"采样"命名 |
| `shots/03-probability.png` | 30s | "今天天气真" → 下一个词的概率表 |
| `shots/04-top-p.png` | 80s | top-p：只保留累计九成的候选 |
| `shots/05-ending.png` | 150s | 回收开头钩子：选择权在你 |

截图来自成片，不是设计稿——所以它们也能当作"画面密度是否达标"的参照：每一屏都有主视觉，没有纯文字页。

---

## 怎么用这套示例

1. **不要复制文案**。选题、句子、比喻都要换成你自己的。
2. 复制 `../templates/episode/` 里的空骨架到你的 `videos/<episode>/`，然后对着本示例的结构填。
3. 填完 `facts.md` 先跑 `check.ps1 -Gate pre-script`，填完 `script.md` + `outline.md` + `script-selfcheck.md` 再跑 `-Gate pre-code`。
4. 想验证工具本身是否正常，可以直接拿本示例跑：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\pipeline\check.ps1 `
  -ProjectDir examples\ep11-sampling -Gate pre-code
```

预期退出码 `0`（`design-intent.md` 的 C13 只给 WARN，不阻断）。

> 本目录的数据来自作者账号，仅用于说明方法；信源引用版权归原作者。
