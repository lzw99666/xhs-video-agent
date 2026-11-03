# cover.py · 阿囤囤风格小红书封面渲染工具

[English](README.md) | **中文版**

把「文字方案（提示词）」直接渲染成成品封面图：HTML/CSS 按阿囤囤规范排版
1080×1440（3:4）→ Playwright 无头 Chrome 截图出 PNG。中文大字全部走 CSS，
不经文生图，杜绝错字。人物图只做圆形裁切 + 描边，不生成/不重绘人脸。

## 用法

```
python tools\cover\cover.py --title "主标题" --person <人物图绝对路径> --out <输出png绝对路径> [可选参数]
```

## 参数

| 参数 | 必填 | 默认 | 说明 |
|---|---|---|---|
| `--title` | 是 | — | 主标题，大字压顶（超粗黑体 + 浅黄填充 + 粗黑描边） |
| `--person` | 二选一 | — | 人物素材图绝对路径（真人照/头像等真实位图）；与 `--no-person` 二选一 |
| `--no-person` | 二选一 | — | 无人物版（无合适真人照时），版式自动垂直居中不留白 |
| `--out` | 是 | — | 输出 PNG 绝对路径，严格 1080×1440 |
| `--subtitle` | 否 | 空 | 副标题（风格 1 白色粗体；风格 4 底部浅黄横幅） |
| `--style` | 否 | 1 | 风格：1=大字压顶风，4=教程清单风；其他编号报错 |
| `--accent` | 否 | `#FDFFA7` | 主色（柔和浅黄），用于标题填充/描边/横幅 |
| `--bg` | 否 | `#0d1117` | 背景色（GitHub 暗色），自动推导渐变与暗角 |
| `--items` | 否 | — | 风格 4 的绿色 ✅ 清单条目，可重复传 |
| `--caption` | 否 | 空 | 底部来源标注文字 |
| `--stickers` | 否 | 开 | 风格 1 主题贴纸开关（emoji 装饰，主题中立），`--no-stickers` 关闭 |
| `--sticker-label` | 否 | 空 | 风格 1 文字卡片贴纸主文案；**不传则无卡片**，禁止沿用上一期文案 |
| `--sticker-sub` | 否 | 空 | 文字卡片贴纸副文案，配合 `--sticker-label` |

## 示例

```powershell
# 风格 1：大字压顶
python tools\cover\cover.py --title "大佬开源压箱底" --subtitle "AI写代码不再翻车" `
  --person "<头像图片路径>" --style 1 `
  --caption "封面人物：某某 公开 GitHub 头像 · 仅作素材引用" --out $env:TEMP\c1.png

# 风格 4：教程清单（人物居右 + 左侧绿色勾选清单 + 底部横幅）
python tools\cover\cover.py --title "一行命令装好 Skills" --subtitle "免费开源可组合" `
  --person "<头像图片路径>" --style 4 `
  --items "一行命令装，自更新不过期" --items "含 tdd / grill-me 技能" --items "免费开源" `
  --out $env:TEMP\c4.png
```

## 依赖

- 本机 Chrome（Playwright channel "chrome"，headless）
- `tools/record/node_modules/playwright-core`（在 `tools/record` 下执行 `npm install`）
- node.exe 在 PATH 中，或用环境变量 `NODE_EXE` 指定绝对路径

HTML 中间文件写到系统临时目录，截图后即删，项目目录不留垃圾。
