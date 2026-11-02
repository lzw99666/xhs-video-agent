# -*- coding: utf-8 -*-
"""
fetch_sources.py — source gathering layer (video line, stage 1 prerequisite)
=====================================================
Given a topic, gather candidate sources from **multiple public-internet sources** and produce sources.md / sources.json
to feed section 1 "Source list" of facts.md. Goal: close the ep06 problem of "taking another person's video notes
as the only source → the output is just a restatement" (single-source restatement; WORKFLOW.md 3.1 hard source-gathering constraint).

Source selection = measured on 2026-10-18 (both reachability and result quality tested; testing only reachability and ignoring quality leads to bad choices):

  [Main source] Xiaohongshu in-platform search_feeds (local MCP HTTP, http://localhost:18060/mcp)
      — same platform, same audience, directly gives "similar notes + real engagement numbers", the benchmark signal
        most needed by the topic layer and blind prediction; the returned note_id + xsecToken can also feed get_feed_detail for full text.
      Prerequisite: mcp\\start-mcp.ps1 has started the service and the account is logged in (when not logged in it returns empty/error and does not block everything).
      Each video only makes 1–2 low-frequency searches to avoid risk control.

  available ✔  www.sogou.com / www.so.com   general-purpose Chinese search, best result quality for technical topics
  available ✔  export.arxiv.org             arXiv paper API (**accepts English strings only**, Chinese strings are skipped automatically)
  optional ✔  api.crossref.org              Crossref literature (returns doi.org landing pages, limited value, off by default)
  optional ✔  api.github.com                repositories (search quota only 10/h, off by default, enable with --github)
  deprecated ✘  cn/www.bing.com             reachable with 200, but for technical search strings only returns dictionary/weather/single-character
                                        definitions and similar irrelevant results (measured with "top_p temperature LLM sampling parameters"
                                        → "TOP (Choi Seung-hyun)"), high availability but zero quality, so not used
  deprecated ✘  www.baidu.com               occasional anti-crawl (returns a ~1.4KB verification page), best-effort only
  unreachable ✘ html/lite.duckduckgo.com, *.wikipedia.org, api.semanticscholar.org,
           raw.githubusercontent.com

Usage (run from the repo root):
  python tools/research/fetch_sources.py --topic "Temperature vs Top-p" `
      --query "LLM temperature top_p differences explained" `
      --out videos/regular-ep07-xxx/sources.md

Arguments:
  --topic     topic label (written into the output header, human-readable)
  --query     web search strings, repeatable; default = uses --topic. **Chinese natural-language strings recommended** (Chinese engines are the main force)
  --query-en  academic/code search strings (English), repeatable; default reuses --query. Chinese strings are skipped automatically by academic sources
  --out       sources.md output path (default ./sources.md); a same-named .json is written too
  --limit     how many items to take per source (default 8)
  --sources   comma-separated, default xhs,sogou,so360,baidu,arxiv; optional crossref github
  --mcp-url   Xiaohongshu MCP address (default http://localhost:18060/mcp)
  --github    equivalent to adding github to --sources (unauthenticated search quota 10 per hour, use with care)
  --no-resolve  do not resolve 360/Sogou redirect links (faster, but the table keeps only intermediary domains; not recommended)
  --local     optional: local material directory. For reference only, not a sourcing constraint; results are listed separately and do not count toward the gate

Exit codes: 0 = source coverage met (≥2 independent domains and ≥1 public-internet domain); 1 = not met; 2 = argument/environment error
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

# Engine/intermediary/DOI resolvers: not counted as "independent sources", and not used as dedupe primary keys
ENGINE_DOMAINS = ("bing.com", "baidu.com", "sogou.com", "so.com", "doi.org")
PUBLIC_KINDS = ("web", "paper", "literature", "code")
ACADEMIC = {"arxiv", "crossref", "github"}
CJK_RE = re.compile(r"[\u3400-\u9fff\uf900-\ufaff]")
RESOLVE = {"resolve": True}


def now_str():
    return datetime.now(TZ).strftime("%Y-%m-%d %H:%M:%S")


def domain_of(url):
    netloc = urllib.parse.urlparse(url).netloc.lower()
    return netloc[4:] if netloc.startswith("www.") else netloc


def strip_tags(s):
    # Fallback: when a snippet is truncated it may leave half a tag; cut from the first unclosed '<'
    t = html.unescape(re.sub(r"<[^>]+>", "", s or ""))
    return re.sub(r"\s+", " ", t.split("<")[0]).strip()


def http_get(url, headers, timeout=25, retries=1):
    """GET, retry on failure; return None when all attempts fail (one source failing does not affect the rest)."""
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
    """Resolve 360/Sogou redirect links to the real URL.

    Measured (2026-10-18): /link?… does not return 302, but a ~250B JS stub:
        <script>window.location.replace("https://real-url")</script>
        <noscript><META http-equiv="refresh" content="0;URL='https://real-url'">
    So just read the stub body + regex extract; no need to follow the redirect (saves a full-page download).
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


# ---------------- General-purpose Chinese search (same h3 parsing) ----------------

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
        out.append({"source": source, "kind": "web", "title": title,
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
    """best-effort: Baidu occasionally anti-crawls and returns a verification page; if parsing fails it just naturally returns 0 items."""
    raw = http_get("https://www.baidu.com/s?wd=" + urllib.parse.quote_plus(q),
                   {"User-Agent": UA_WEB, "Accept-Language": "zh-CN,zh;q=0.9",
                    "Accept": "text/html,application/xhtml+xml"})
    if not raw or len(raw) < 20000:        # the verification page is about 1.4KB, so treat it as blocked
        return []
    return parse_h3(raw.decode("utf-8", "replace"),
                    r'<h3[^>]*class="t[^"]*"[^>]*>', "https://www.baidu.com",
                    limit, "baidu")


# ---------------- Academic / code ----------------

def search_arxiv(q, limit):
    # Measured: without quotes arXiv matches "word OR word" and returns piles of physics/biology papers
    # ("nucleus sampling top-p temperature" → neutrinos/superfluid helium); after adding quotes it becomes phrase matching and all results are relevant.
    # If the caller already used arXiv field syntax (all:/abs:/ti:), pass it through as-is.
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
            out.append({"source": "arxiv", "kind": "paper", "title": title, "url": link,
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
            out.append({"source": "crossref", "kind": "literature", "title": strip_tags(title),
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
    return [{"source": "github", "kind": "code", "title": it.get("full_name", ""),
             "url": it.get("html_url", ""), "snippet": (it.get("description") or "")[:400],
             "date": (it.get("pushed_at") or "")[:10]} for it in items]


def search_local(root, queries, limit):
    """Local material search (optional reference, does not count toward the gate)."""
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
                out.append({"source": "local", "kind": "local", "title": str(p),
                            "url": "file:///" + str(p).replace("\\", "/"),
                            "snippet": re.sub(r"\s+", " ", t[max(0, m.start() - 60): m.end() + 120]).strip(),
                            "date": ""})
                break
    return out


SOURCES = {
    "xhs": ("xhs", None),          # placeholder, implemented below (depends on the MCP client)
    "sogou": ("web", search_sogou),
    "so360": ("web", search_so360),
    "baidu": ("web", search_baidu),
    "arxiv": ("paper", search_arxiv),
    "crossref": ("literature", search_crossref),
    "github": ("code", search_github),
}


# ---------------- Main source: Xiaohongshu in-platform (local MCP HTTP) ----------------

class XhsMcp:
    """Minimal streamable-http client for xiaohongshu-mcp (initialize → tools/call).

    The service is started by mcp\\start-mcp.ps1 (localhost:18060/mcp). Responses are SSE; take the data: line.
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
    """Xiaohongshu in-platform search (main source): returns similar notes + real engagement numbers + note_id/xsecToken."""
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
            "source": "xhs", "kind": "xhs",
            "title": nc.get("displayTitle") or "(untitled)",
            "url": "https://www.xiaohongshu.com/explore/" + nid,
            "snippet": "%s | %s likes / %s saves / %s comments" % (user, it.get("likedCount", "-"),
                                                     it.get("collectedCount", "-"),
                                                     it.get("commentCount", "-")),
            "date": "",
            "author": user, "note_id": nid, "xsec_token": f.get("xsecToken", ""),
            "note_type": nc.get("type", ""),
            "liked": it.get("likedCount", "-"), "collected": it.get("collectedCount", "-"),
        })
    return out


SOURCES["xhs"] = ("xhs", search_xhs)


# ---------------- Aggregation / output ----------------

def dedupe(items):
    seen, seen_title, out = set(), set(), []
    for it in items:
        u = it["url"]
        d = domain_of(u)
        # An unresolved redirect link shares a domain+path like sogou.com/link, so the whole URL must be the key
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
    """Public-internet source coverage verdict: ≥2 independent domains (not search engines/intermediaries) and ≥1 public-internet domain."""
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
    L.append("# sources.md · source research card (multi-source public internet)\n")
    L.append("> Auto-generated by `tools\\research\\fetch_sources.py`; do not edit the structure by hand, put notes under \"3. Manual verification\".")
    L.append("> Purpose: a candidate source pool for section 1 \"Source list\" of facts.md. **≥2 independent sources, at least 1 from the public internet**, is required before trusting it.\n")
    L.append("- Topic label: %s" % topic)
    L.append("- Search strings: %s" % " / ".join(queries))
    L.append("- Generated at: %s" % now_str())
    L.append("- Source status: %s" % "; ".join("%s=%s" % (k, v) for k, v in status.items()))
    n_xhs = sum(1 for i in items if i["kind"] == "xhs")
    L.append("- **Verdict: %s** — %d in-platform benchmark notes; %d independent public-internet domains: %s; largest single-domain share %.0f%%"
             % ("PASS" if ok else "FAIL", n_xhs, len(doms),
                " / ".join("%s(%d)" % (d, counts[d]) for d in doms) or "none",
                top_share * 100))
    if n_xhs == 0:
        L.append("  - ⚠️ 0 in-platform benchmark notes: confirm `mcp\\start-mcp.ps1` is running and the account is logged in (search_feeds requires a login session).")
    if not ok:
        L.append("  - ⚠️ Not met: fewer than 2 independent sources — do not write facts based on this (single-source restatement); add public-internet sources or change the topic.")
    elif top_share > 0.6:
        L.append("  - ⚠️ Single-domain share >60%: sources are concentrated; beware of a \"repackaged single-source restatement\"; trace every key data point back to its source.")
    L.append("")

    for kind in ("xhs", "web", "paper", "literature", "code"):
        group = [i for i in items if i["kind"] == kind]
        if not group:
            continue
        if kind == "xhs":
            L.append("## 1. Xiaohongshu in-platform benchmarks (%d items) — same platform, same audience; directly usable for the topic layer and blind prediction" % len(group))
            L.append("")
            L.append("| # | Title | Author | Likes | Saves | Comments | Type | note_id |")
            L.append("|---|---|---|---|---|---|---|---|")
            for n, it in enumerate(group, 1):
                L.append("| %d | %s | %s | %s | %s | %s | %s | `%s` |"
                         % (n, it["title"].replace("|", "/"), it.get("author", ""),
                            it.get("liked", "-"), it.get("collected", "-"),
                            (it.get("snippet", "").split("/")[-1].strip() or "-"),
                            it.get("note_type", ""), it.get("note_id", "")))
            L.append("")
            L.append("> Full-text drill-down: call MCP `get_feed_detail` on the target note (requires `note_id` + `xsec_token`).")
            L.append("")
            continue
        label = {"web": "Web pages", "paper": "Papers", "literature": "Literature", "code": "Code"}[kind]
        L.append("## 1.%s · %s (%d items)" % (kind, label, len(group)))
        L.append("")
        L.append("| # | Title | Domain | Date | Link |")
        L.append("|---|---|---|---|---|")
        for n, it in enumerate(group, 1):
            L.append("| %s-%d | %s | %s | %s | %s |"
                     % (it["source"], n, it["title"].replace("|", "/"),
                        domain_of(it["url"]), it["date"] or "-", it["url"]))
        L.append("")
        for n, it in enumerate(group, 1):
            if it["snippet"]:
                L.append("- **%s-%d**: %s" % (it["source"], n, it["snippet"].replace("|", "/")))
        L.append("")

    if local_items:
        L.append("## 2. Local materials (optional reference, not counted toward the gate)")
        L.append("")
        for it in local_items:
            L.append("- `%s` — %s" % (it["title"], it["snippet"]))
        L.append("")

    L.append("## 3. Manual verification (to be filled in)")
    L.append("")
    L.append("- [ ] Verify every key data point against its source (open the link and confirm the numbers/conclusion match)")
    L.append("- [ ] Reused examples / numbers from others are cited in facts.md")
    L.append("- [ ] No zero-cross single-source restatement (each key conclusion is supported by ≥2 independent sources)")
    L.append("- [ ] Ads / SEO farms / irrelevant results removed")
    L.append("")
    return "\n".join(L)


def main():
    ap = argparse.ArgumentParser(description="Multi-source public-internet source research (stage 1 prerequisite)")
    ap.add_argument("--topic", required=True, help="topic label")
    ap.add_argument("--query", action="append", default=None, help="web search strings, repeatable")
    ap.add_argument("--query-en", action="append", default=None, help="academic/code search strings (English), repeatable")
    ap.add_argument("--out", default="sources.md", help="sources.md output path")
    ap.add_argument("--limit", type=int, default=8, help="max items per source")
    ap.add_argument("--sources", default="xhs,sogou,so360,baidu,arxiv", help="comma-separated sources")
    ap.add_argument("--mcp-url", default="http://localhost:18060/mcp", help="Xiaohongshu MCP address")
    ap.add_argument("--github", action="store_true", help="add the github source (costly quota)")
    ap.add_argument("--no-resolve", action="store_true", help="do not resolve redirect links")
    ap.add_argument("--local", default=None, help="optional: local material directory")
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
        print("ERROR: unknown source %s (available: %s)" % (bad, list(SOURCES)))
        return 2

    q_web = args.query or [args.topic]
    q_acad = args.query_en or q_web
    # arXiv/Crossref/GitHub only accept English strings: feeding Chinese strings returns piles of unrelated physics/biology papers, so skip them
    acad_cjk = any(CJK_RE.search(q) for q in q_acad)
    queries = q_web + [q for q in q_acad if q not in q_web]

    all_items, status = [], {}
    for n in names:
        if n in ACADEMIC and acad_cjk and not args.query_en:
            status[n] = "skipped (Chinese string)"
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
            got, status[n] = [], "error:%s" % e
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

    print("\nverdict: %s | independent source domains %d | public-internet items %d | largest single-domain share %.0f%%"
          % ("PASS" if ok else "FAIL", len(doms), sum(counts.values()), top_share * 100))
    print("output: %s  +  %s" % (out, out.with_suffix(".json")))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
