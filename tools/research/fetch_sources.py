# -*- coding: utf-8 -*-
"""
fetch_sources.py —— 素材获取层（视频线 工序一 前置）
=====================================================
给一个选题，从**公网多源**抓候选来源，产出 sources.md / sources.json，
喂给 facts.md 的「一、信源清单」。目的：堵住 ep06 那种「拿一份他人视频的笔记
当唯一信源 → 产出即复述」的单源复述问题（WORKFLOW.md 3.1 素材获取硬约束）。

源选型 = 2026-10-18 实测（可达域 + 结果质量双测；只测可达不看质量会踩坑）：

  【主源】小红书站内 search_feeds（本地 MCP HTTP，http://localhost:18060/mcp）
      —— 同平台、同受众，直接给出「同类笔记 + 真实互动数」，是选题层与盲预测
         最需要的对标信号；返回的 note_id + xsecToken 还能接 get_feed_detail 取全文。
      前置：mcp\start-mcp.ps1 已拉起服务 + 账号已登录（未登录返回空/报错，不阻断全局）。
      单支视频只调 1~2 次低频搜索，避开风控。

  可用 ✔  www.sogou.com / www.so.com   中文通用检索，技术选题结果质量最好
  可用 ✔  export.arxiv.org             arXiv 论文 API（**只吃英文串**，中文串自动跳过）
  可选 ✔  api.crossref.org             Crossref 文献（返回 doi.org 落地页，价值有限，默认关）
  可选 ✔  api.github.com               仓库（search 配额仅 10/h，默认关闭，--github 开）
  弃用 ✘  cn/www.bing.com              可达 200，但对技术检索串只回词典/天气/单字释义等
                                        无关结果（实测 "top_p temperature LLM 采样参数"
                                        → "TOP（崔胜铉）"），可用性高但质量为零，故不用
  弃用 ✘  www.baidu.com                偶发反爬（返回 ~1.4KB 验证页），仅作 best-effort
  不可达 ✘ html/lite.duckduckgo.com、*.wikipedia.org、api.semanticscholar.org、
           raw.githubusercontent.com

用法（在仓库根目录下运行）：
  python tools/research/fetch_sources.py --topic "Temperature 与 Top-p" `
      --query "大模型 temperature top_p 区别 详解" `
      --out videos/regular-ep07-xxx/sources.md

参数：
  --topic     选题标签（写进产物抬头，人类可读）
  --query     网页检索串，可重复；缺省 = 用 --topic。**建议给中文自然语言串**（中文引擎为主力）
  --query-en  学术/代码检索串（英文），可重复；缺省复用 --query。中文串会被学术源自动跳过
  --out       sources.md 输出路径（缺省 ./sources.md）；同名 .json 一并写出
  --limit     每个源最多取多少条（缺省 8）
  --sources   逗号分隔，缺省 xhs,sogou,so360,baidu,arxiv；可选 crossref github
  --mcp-url   小红书 MCP 地址（缺省 http://localhost:18060/mcp）
  --github    等价于在 --sources 里加 github（未认证 search 配额 10 次/小时，慎用）
  --no-resolve  不解析 360/搜狗的跳转链接（更快，但表里只剩中转域，不推荐）
  --local     可选：本地资料目录。仅作参考，不是取材约束，结果单列不参与闸门判定

退出码：0 = 来源覆盖达标（≥2 个独立域 且 ≥1 个公网域）；1 = 未达标；2 = 参数/环境错误
"""

import argparse
import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

TZ = timezone(timedelta(hours=8))
UA_WEB = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
UA_BOT = "xhs-video-agent/1.0 (+workflow)"
NS = {"a": "http://www.w3.org/2005/Atom"}

# 引擎自身/中转/DOI 解析器：不算「独立来源」，也不作为去重主键
ENGINE_DOMAINS = ("bing.com", "baidu.com", "sogou.com", "so.com", "doi.org")
PUBLIC_KINDS = ("网页", "论文", "文献", "代码")
ACADEMIC = {"arxiv", "crossref", "github"}
CJK_RE = re.compile(r"[\u3400-\u9fff\uf900-\ufaff]")
RESOLVE = {"resolve": True}


def now_str():
    return datetime.now(TZ).strftime("%Y-%m-%d %H:%M:%S")


def domain_of(url):
    netloc = urllib.parse.urlparse(url).netloc.lower()
    return netloc[4:] if netloc.startswith("www.") else netloc


def strip_tags(s):
    # 兜底：片段被截断时可能残留半截标签，从第一个未闭合 '<' 处截断
    t = html.unescape(re.sub(r"<[^>]+>", "", s or ""))
    return re.sub(r"\s+", " ", t.split("<")[0]).strip()


def http_get(url, headers, timeout=25, retries=1):
    """GET，失败重试；全失败返回 None（单源挂掉不影响全局）。"""
    for i in range(retries + 1):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as f:
                return f.read()
        except Exception:
            if i < retries:
                time.sleep(2)
    return None


def resolve_url(url, base=""):
    """解析 360/搜狗的中转链接拿真实 URL。

    实测（2026-10-18）：/link?… 不返回 302，而是回一个 ~250B 的 JS stub：
        <script>window.location.replace("https://真实地址")</script>
        <noscript><META http-equiv="refresh" content="0;URL='https://真实地址'">
    所以只需读 stub 体 + 正则提取，无需跟随跳转（省一次全页下载）。
    """
    if not RESOLVE["resolve"]:
        return url
    if url.startswith("/"):
        url = base.rstrip("/") + url
    if not url.startswith("http"):
        return url
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA_WEB})
        with urllib.request.urlopen(req, timeout=12) as f:
            txt = f.read(4096).decode("utf-8", "replace")
    except Exception:
        return url
    m = (re.search(r'location\.replace\("([^"]+)"\)', txt)
         or re.search(r"URL='([^']+)'", txt))
    real = html.unescape(m.group(1)) if m else ""
    return real if real.startswith("http") else url


# ---------------- 中文通用检索（同一套 h3 解析） ----------------

def parse_h3(txt, h3_re, base, limit, source):
    out = []
    for part in re.split(h3_re, txt)[1:]:
        if len(out) >= limit:
            break
        a = re.search(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', part, re.S)
        if not a:
            continue
        title = strip_tags(a.group(2))
        if not title:
            continue
        link = resolve_url(html.unescape(a.group(1)), base)
        nxt = part.find("<h3")
        body = part[:nxt] if nxt > 0 else part[:3000]
        out.append({"source": source, "kind": "网页", "title": title,
                    "url": link, "snippet": strip_tags(body)[:400], "date": ""})
    return out


def search_sogou(q, limit):
    raw = http_get("https://www.sogou.com/web?query=" + urllib.parse.quote_plus(q),
                   {"User-Agent": UA_WEB, "Accept-Language": "zh-CN,zh;q=0.9",
                    "Accept": "text/html,application/xhtml+xml"})
    if not raw:
        return []
    return parse_h3(raw.decode("utf-8", "replace"),
                    r'<h3[^>]*class="vr-title[^"]*"[^>]*>', "https://www.sogou.com",
                    limit, "sogou")


def search_so360(q, limit):
    raw = http_get("https://www.so.com/s?q=" + urllib.parse.quote_plus(q),
                   {"User-Agent": UA_WEB, "Accept-Language": "zh-CN,zh;q=0.9",
                    "Accept": "text/html,application/xhtml+xml"})
    if not raw:
        return []
    return parse_h3(raw.decode("utf-8", "replace"),
                    r'<h3[^>]*class="res-title[^"]*"[^>]*>', "https://www.so.com",
                    limit, "so360")


def search_baidu(q, limit):
    """best-effort：百度偶发反爬返回验证页，解析不到就自然返回 0 条。"""
    raw = http_get("https://www.baidu.com/s?wd=" + urllib.parse.quote_plus(q),
                   {"User-Agent": UA_WEB, "Accept-Language": "zh-CN,zh;q=0.9",
                    "Accept": "text/html,application/xhtml+xml"})
    if not raw or len(raw) < 20000:        # 验证页约 1.4KB，直接判为被拦
        return []
    return parse_h3(raw.decode("utf-8", "replace"),
                    r'<h3[^>]*class="t[^"]*"[^>]*>', "https://www.baidu.com",
                    limit, "baidu")


# ---------------- 学术 / 代码 ----------------

def search_arxiv(q, limit):
    # 实测：不带引号时 arXiv 按「词 OR 词」匹配，会回一堆物理/生物论文
    # （"nucleus sampling top-p temperature" → 中微子/超流氦）；加引号变短语匹配后全部相关。
    # 若调用方已用 arXiv 字段语法（all:/abs:/ti:），则原样透传。
    q = q.strip()
    if ":" not in q and " " in q:
        q = '"%s"' % q
    url = ("http://export.arxiv.org/api/query?search_query=all:%s"
           "&start=0&max_results=%d&sortBy=relevance"
           % (urllib.parse.quote_plus(q), limit))
    raw = http_get(url, {"User-Agent": UA_BOT})
    if not raw:
        return []
    try:
        root = ET.fromstring(raw)
    except Exception:
        return []
    out = []
    for e in root.findall("a:entry", NS):
        title = strip_tags(e.findtext("a:title", "", NS))
        link = (e.findtext("a:id", "", NS) or "").strip()
        if title and link:
            out.append({"source": "arxiv", "kind": "论文", "title": title, "url": link,
                        "snippet": strip_tags(e.findtext("a:summary", "", NS))[:400],
                        "date": (e.findtext("a:published", "", NS) or "")[:10]})
    return out


def search_crossref(q, limit):
    url = ("https://api.crossref.org/works?query=%s&rows=%d"
           "&select=title,URL,DOI,issued,container-title"
           % (urllib.parse.quote_plus(q), limit))
    raw = http_get(url, {"User-Agent": UA_BOT, "Accept": "application/json"})
    if not raw:
        return []
    try:
        items = json.loads(raw.decode("utf-8", "replace"))["message"]["items"]
    except Exception:
        return []
    out = []
    for it in items:
        title = (it.get("title") or [""])[0]
        link = it.get("URL") or ("https://doi.org/" + it["DOI"] if it.get("DOI") else "")
        parts = (it.get("issued", {}).get("date-parts") or [[""]])[0]
        if title and link:
            out.append({"source": "crossref", "kind": "文献", "title": strip_tags(title),
                        "url": link, "snippet": (it.get("container-title") or [""])[0][:200],
                        "date": "-".join(str(x) for x in parts if x)})
    return out


def search_github(q, limit):
    url = ("https://api.github.com/search/repositories?q=%s&sort=stars&per_page=%d"
           % (urllib.parse.quote_plus(q), max(1, min(limit, 30))))
    raw = http_get(url, {"User-Agent": UA_BOT, "Accept": "application/vnd.github+json"})
    if not raw:
        return []
    try:
        items = json.loads(raw.decode("utf-8", "replace")).get("items", [])
    except Exception:
        return []
    return [{"source": "github", "kind": "代码", "title": it.get("full_name", ""),
             "url": it.get("html_url", ""), "snippet": (it.get("description") or "")[:400],
             "date": (it.get("pushed_at") or "")[:10]} for it in items]


def search_local(root, queries, limit):
    """本地资料检索（可选参考，不参与闸门判定）。"""
    base = Path(root)
    if not base.is_dir():
        return []
    pats = [re.compile(re.escape(q), re.I) for q in queries if q]
    out = []
    for p in sorted(base.rglob("*")):
        if len(out) >= limit:
            break
        if not p.is_file() or p.suffix.lower() not in {".md", ".txt", ".py", ".json", ".rst"}:
            continue
        try:
            t = p.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        for pat in pats:
            m = pat.search(t)
            if m:
                out.append({"source": "local", "kind": "本地", "title": str(p),
                            "url": "file:///" + str(p).replace("\\", "/"),
                            "snippet": re.sub(r"\s+", " ", t[max(0, m.start() - 60): m.end() + 120]).strip(),
                            "date": ""})
                break
    return out


SOURCES = {
    "xhs": ("站内", None),          # 占位，实现在下方（依赖 MCP 客户端）
    "sogou": ("网页", search_sogou),
    "so360": ("网页", search_so360),
    "baidu": ("网页", search_baidu),
    "arxiv": ("论文", search_arxiv),
    "crossref": ("文献", search_crossref),
    "github": ("代码", search_github),
}


# ---------------- 主源：小红书站内（本地 MCP HTTP） ----------------

class XhsMcp:
    """xiaohongshu-mcp 的极简 streamable-http 客户端（initialize → tools/call）。

    服务由 mcp\\start-mcp.ps1 拉起（localhost:18060/mcp）。响应是 SSE，取 data: 行。
    """

    def __init__(self, url):
        self.url = url
        self.session = None

    def _post(self, payload):
        hdr = {"Content-Type": "application/json",
               "Accept": "application/json, text/event-stream"}
        if self.session:
            hdr["Mcp-Session-Id"] = self.session
        req = urllib.request.Request(self.url, data=json.dumps(payload).encode(), headers=hdr)
        with urllib.request.urlopen(req, timeout=60) as r:
            if r.headers.get("Mcp-Session-Id"):
                self.session = r.headers.get("Mcp-Session-Id")
            body = r.read().decode("utf-8", "replace")
        data = None
        for line in body.splitlines():
            if line.startswith("data:"):
                data = line[5:].strip()
        return json.loads(data) if data else (json.loads(body) if body.strip() else None)

    def init(self):
        self._post({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                    "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                               "clientInfo": {"name": "fetch_sources", "version": "1.0"}}})
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call(self, name, arguments):
        d = self._post({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                        "params": {"name": name, "arguments": arguments}})
        for c in ((d or {}).get("result") or {}).get("content") or []:
            if c.get("type") == "text":
                try:
                    return json.loads(c["text"])
                except Exception:
                    return {"raw": c["text"]}
        return None


XHS = {"client": None, "url": "http://localhost:18060/mcp"}


def search_xhs(q, limit):
    """小红书站内搜索（主源）：返回同类笔记 + 真实互动数 + note_id/xsecToken。"""
    if XHS["client"] is None:
        c = XhsMcp(XHS["url"])
        c.init()
        XHS["client"] = c
    data = XHS["client"].call("search_feeds", {"keyword": q})
    out = []
    for f in ((data or {}).get("feeds") or [])[:limit]:
        nc = f.get("noteCard") or {}
        user = (nc.get("user") or {}).get("nickname", "")
        it = nc.get("interactInfo") or {}
        nid = f.get("id", "")
        out.append({
            "source": "xhs", "kind": "站内",
            "title": nc.get("displayTitle") or "(无标题)",
            "url": "https://www.xiaohongshu.com/explore/" + nid,
            "snippet": "%s｜%s 赞 / %s 藏 / %s 评" % (user, it.get("likedCount", "-"),
                                                     it.get("collectedCount", "-"),
                                                     it.get("commentCount", "-")),
            "date": "",
            "author": user, "note_id": nid, "xsec_token": f.get("xsecToken", ""),
            "note_type": nc.get("type", ""),
            "liked": it.get("likedCount", "-"), "collected": it.get("collectedCount", "-"),
        })
    return out


SOURCES["xhs"] = ("站内", search_xhs)


# ---------------- 汇总 / 输出 ----------------

def dedupe(items):
    seen, seen_title, out = set(), set(), []
    for it in items:
        u = it["url"]
        d = domain_of(u)
        # 未解析成功的中转链接会共享 sogou.com/link 这样的域+路径，必须用整条 URL 当键
        key = u if d.endswith(ENGINE_DOMAINS) else d + urllib.parse.urlparse(u).path.rstrip("/")
        tkey = re.sub(r"\s+", "", it["title"])[:40]
        if key in seen or (tkey and tkey in seen_title):
            continue
        seen.add(key)
        if tkey:
            seen_title.add(tkey)
        out.append(it)
    return out


def verdict(items):
    """公网来源覆盖判定：≥2 个独立域（非搜索引擎/中转）且 ≥1 个公网域。"""
    pubs = [i for i in items if i["kind"] in PUBLIC_KINDS and i["url"].startswith("http")]
    counts = {}
    for i in pubs:
        d = domain_of(i["url"])
        counts[d] = counts.get(d, 0) + 1
    real = {d: c for d, c in counts.items() if d and not d.endswith(ENGINE_DOMAINS)}
    top_share = (max(real.values()) / sum(real.values())) if real else 0.0
    return (len(real) >= 2 and len(pubs) >= 1), sorted(real), real, top_share


def render_md(topic, queries, items, local_items, ok, doms, counts, top_share, status):
    L = []
    L.append("# sources.md · 素材检索卡（公网多源）\n")
    L.append("> 由 `tools\\research\\fetch_sources.py` 自动生成；结构勿手改，补注写在「三、人工核验」。")
    L.append("> 用途：作为 facts.md「一、信源清单」的候选来源池。**≥2 个独立来源、其中 ≥1 个公网**方可采信。\n")
    L.append("- 选题标签：%s" % topic)
    L.append("- 检索串：%s" % " / ".join(queries))
    L.append("- 生成时间：%s" % now_str())
    L.append("- 源可用性：%s" % "；".join("%s=%s" % (k, v) for k, v in status.items()))
    n_xhs = sum(1 for i in items if i["kind"] == "站内")
    L.append("- **判定：%s** — 站内对标 %d 条；公网独立来源域 %d 个：%s；最大单域占比 %.0f%%"
             % ("PASS" if ok else "FAIL", n_xhs, len(doms),
                " / ".join("%s(%d)" % (d, counts[d]) for d in doms) or "无",
                top_share * 100))
    if n_xhs == 0:
        L.append("  - ⚠️ 站内对标 0 条：确认 `mcp\\start-mcp.ps1` 已拉起且账号已登录（search_feeds 需登录态）。")
    if not ok:
        L.append("  - ⚠️ 未达标：独立来源不足 2 个 —— 不得据此写 facts（单源复述）；补齐公网来源或改选题。")
    elif top_share > 0.6:
        L.append("  - ⚠️ 单域占比 >60%：来源集中，警惕「换皮单源复述」；关键数据逐条回源。")
    L.append("")

    for kind in ("站内", "网页", "论文", "文献", "代码"):
        group = [i for i in items if i["kind"] == kind]
        if not group:
            continue
        if kind == "站内":
            L.append("## 一、小红书站内对标（%d 条）—— 同平台同受众，选题层与盲预测直接可用" % len(group))
            L.append("")
            L.append("| # | 标题 | 作者 | 赞 | 藏 | 评 | 类型 | note_id |")
            L.append("|---|---|---|---|---|---|---|---|")
            for n, it in enumerate(group, 1):
                L.append("| %d | %s | %s | %s | %s | %s | %s | `%s` |"
                         % (n, it["title"].replace("|", "/"), it.get("author", ""),
                            it.get("liked", "-"), it.get("collected", "-"),
                            (it.get("snippet", "").split("/")[-1].strip() or "-"),
                            it.get("note_type", ""), it.get("note_id", "")))
            L.append("")
            L.append("> 下钻全文：对目标笔记调 MCP `get_feed_detail`（需带 `note_id` + `xsec_token`）。")
            L.append("")
            continue
        L.append("## 一.%s · %s（%d 条）" % (kind, kind, len(group)))
        L.append("")
        L.append("| # | 标题 | 域名 | 日期 | 链接 |")
        L.append("|---|---|---|---|---|")
        for n, it in enumerate(group, 1):
            L.append("| %s-%d | %s | %s | %s | %s |"
                     % (it["source"], n, it["title"].replace("|", "/"),
                        domain_of(it["url"]), it["date"] or "-", it["url"]))
        L.append("")
        for n, it in enumerate(group, 1):
            if it["snippet"]:
                L.append("- **%s-%d**：%s" % (it["source"], n, it["snippet"].replace("|", "/")))
        L.append("")

    if local_items:
        L.append("## 二、本地资料（可选参考，不参与闸门判定）")
        L.append("")
        for it in local_items:
            L.append("- `%s` — %s" % (it["title"], it["snippet"]))
        L.append("")

    L.append("## 三、人工核验（待填）")
    L.append("")
    L.append("- [ ] 关键数据逐条回源核对（打开链接确认数字/结论一致）")
    L.append("- [ ] 复用他人的示例 / 数字已在 facts.md 注明出处")
    L.append("- [ ] 不存在零交叉单源复述（每条关键结论 ≥2 个独立来源支撑）")
    L.append("- [ ] 已剔除广告/SEO 农场/无关结果")
    L.append("")
    return "\n".join(L)


def main():
    ap = argparse.ArgumentParser(description="公网多源素材检索（工序一前置）")
    ap.add_argument("--topic", required=True, help="选题标签")
    ap.add_argument("--query", action="append", default=None, help="网页检索串，可重复")
    ap.add_argument("--query-en", action="append", default=None, help="学术/代码检索串（英文），可重复")
    ap.add_argument("--out", default="sources.md", help="sources.md 输出路径")
    ap.add_argument("--limit", type=int, default=8, help="每源条数上限")
    ap.add_argument("--sources", default="xhs,sogou,so360,baidu,arxiv", help="逗号分隔的源")
    ap.add_argument("--mcp-url", default="http://localhost:18060/mcp", help="小红书 MCP 地址")
    ap.add_argument("--github", action="store_true", help="加入 github 源（配额贵）")
    ap.add_argument("--no-resolve", action="store_true", help="不解析跳转链接")
    ap.add_argument("--local", default=None, help="可选：本地资料目录")
    args = ap.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    RESOLVE["resolve"] = not args.no_resolve
    XHS["url"] = args.mcp_url
    names = [s.strip() for s in args.sources.split(",") if s.strip()]
    if args.github and "github" not in names:
        names.append("github")
    bad = [n for n in names if n not in SOURCES]
    if bad:
        print("ERROR: 未知来源 %s（可选 %s）" % (bad, list(SOURCES)))
        return 2

    q_web = args.query or [args.topic]
    q_acad = args.query_en or q_web
    # arXiv/Crossref/GitHub 只吃英文串：喂中文串会回一堆无关的物理/生物论文，直接跳过
    acad_cjk = any(CJK_RE.search(q) for q in q_acad)
    queries = q_web + [q for q in q_acad if q not in q_web]

    all_items, status = [], {}
    for n in names:
        if n in ACADEMIC and acad_cjk and not args.query_en:
            status[n] = "跳过(中文串)"
            print("[%s] %s" % (n, status[n]))
            continue
        fn = SOURCES[n][1]
        qs = q_acad if n in ACADEMIC else q_web
        try:
            got = []
            for q in qs:
                got += fn(q, args.limit)
            status[n] = "OK(%d)" % len(got)
        except Exception as e:
            got, status[n] = [], "异常:%s" % e
        all_items += got
        print("[%s] %s" % (n, status[n]))

    items = dedupe(all_items)
    local_items = search_local(args.local, queries, args.limit) if args.local else []
    ok, doms, counts, top_share = verdict(items)

    out = Path(args.out)
    if out.parent and not out.parent.exists():
        out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render_md(args.topic, queries, items, local_items,
                             ok, doms, counts, top_share, status), encoding="utf-8")
    out.with_suffix(".json").write_text(json.dumps(
        {"topic": args.topic, "queries": queries, "generated_at": now_str(),
         "verdict": "PASS" if ok else "FAIL", "domains": doms,
         "domain_counts": counts, "items": items, "local": local_items},
        ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n判定: %s | 独立来源域 %d | 公网条目 %d | 最大单域占比 %.0f%%"
          % ("PASS" if ok else "FAIL", len(doms), sum(counts.values()), top_share * 100))
    print("产物: %s  +  %s" % (out, out.with_suffix(".json")))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
