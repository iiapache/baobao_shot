#!/usr/bin/env python3
"""将 compliance/policies/*.md 转为 docs/compliance/legal/<slug>/index.html（COMP-02）。"""
from __future__ import annotations

import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "compliance" / "policies"
OUTPUT_ROOT = ROOT / "docs" / "compliance" / "legal"

POLICY_FILES = [
    "privacy-policy-cn.md",
    "privacy-policy-os.md",
    "terms-of-service.md",
    "deep-synthesis-notice.md",
    "third-party-sdk-list.md",
]

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
BOLD_RE = re.compile(r"\*\*([^*]+)\*\*")
ITALIC_RE = re.compile(r"(?<!\*)\*([^*]+)\*(?!\*)")


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}, text
    meta: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        meta[key.strip()] = value.strip()
    return meta, text[match.end() :]


def slug_from_link(target: str, current_slug: str) -> str:
    target = target.strip()
    if target.startswith("http://") or target.startswith("https://"):
        return target
    name = Path(target).stem
    if name.endswith(".md"):
        name = Path(name).stem
    return f"../{name}/"


def inline_format(text: str, current_slug: str) -> str:
    escaped = html.escape(text)

    def link_sub(match: re.Match[str]) -> str:
        label, href = match.group(1), match.group(2)
        resolved = slug_from_link(href, current_slug)
        if resolved.startswith("http"):
            return f'<a href="{html.escape(resolved, quote=True)}">{html.escape(label)}</a>'
        return f'<a href="{html.escape(resolved, quote=True)}">{html.escape(label)}</a>'

    escaped = LINK_RE.sub(link_sub, escaped)
    escaped = BOLD_RE.sub(r"<strong>\1</strong>", escaped)
    escaped = ITALIC_RE.sub(r"<em>\1</em>", escaped)
    return escaped


def is_table_row(line: str) -> bool:
    stripped = line.strip()
    return stripped.startswith("|") and stripped.endswith("|")


def is_table_separator(line: str) -> bool:
    stripped = line.strip().strip("|")
    cells = [cell.strip() for cell in stripped.split("|")]
    return all(re.fullmatch(r":?-{3,}:?", cell or "---") for cell in cells if cell)


def parse_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def markdown_to_html(body: str, slug: str) -> str:
    lines = body.splitlines()
    out: list[str] = []
    i = 0
    in_ul = False
    in_ol = False

    def close_lists() -> None:
        nonlocal in_ul, in_ol
        if in_ul:
            out.append("</ul>")
            in_ul = False
        if in_ol:
            out.append("</ol>")
            in_ol = False

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            close_lists()
            i += 1
            continue

        if stripped == "---":
            close_lists()
            out.append("<hr />")
            i += 1
            continue

        if stripped.startswith("#"):
            close_lists()
            level = len(stripped) - len(stripped.lstrip("#"))
            title = stripped[level:].strip()
            level = min(max(level, 1), 4)
            out.append(f"<h{level}>{inline_format(title, slug)}</h{level}>")
            i += 1
            continue

        if is_table_row(stripped):
            close_lists()
            table_lines = []
            while i < len(lines) and is_table_row(lines[i].strip()):
                table_lines.append(lines[i].strip())
                i += 1
            if len(table_lines) >= 2 and is_table_separator(table_lines[1]):
                headers = parse_table_row(table_lines[0])
                out.append("<table><thead><tr>")
                for header in headers:
                    out.append(f"<th>{inline_format(header, slug)}</th>")
                out.append("</tr></thead><tbody>")
                for row_line in table_lines[2:]:
                    cells = parse_table_row(row_line)
                    out.append("<tr>")
                    for cell in cells:
                        out.append(f"<td>{inline_format(cell, slug)}</td>")
                    out.append("</tr>")
                out.append("</tbody></table>")
            continue

        if stripped.startswith("- "):
            if not in_ul:
                close_lists()
                out.append("<ul>")
                in_ul = True
            out.append(f"<li>{inline_format(stripped[2:].strip(), slug)}</li>")
            i += 1
            continue

        numbered = re.match(r"^(\d+)\.\s+(.*)$", stripped)
        if numbered:
            if not in_ol:
                close_lists()
                out.append("<ol>")
                in_ol = True
            out.append(f"<li>{inline_format(numbered.group(2), slug)}</li>")
            i += 1
            continue

        close_lists()
        out.append(f"<p>{inline_format(stripped, slug)}</p>")
        i += 1

    close_lists()
    return "\n".join(out)


def build_page(meta: dict[str, str], body_html: str) -> str:
    title = meta.get("title", "合规文档")
    version = meta.get("version", "v1.0.0")
    effective = meta.get("effective_date", "")
    locale = meta.get("locale", "zh-CN")
    lang = "en" if locale.startswith("en") else "zh-CN"

    return f"""<!DOCTYPE html>
<html lang="{html.escape(lang)}">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="robots" content="index,follow" />
  <title>{html.escape(title)} · 宝宝成长相机</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #faf9f7;
      --surface: #ffffff;
      --text: #1a1a1a;
      --muted: #5c5c5c;
      --accent: #c45c4a;
      --border: #e8e4df;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.65;
      font-size: 16px;
    }}
    main {{
      max-width: 720px;
      margin: 0 auto;
      padding: 2rem 1.25rem 3rem;
      background: var(--surface);
      min-height: 100vh;
      box-shadow: 0 0 0 1px var(--border);
    }}
    .doc-meta {{
      margin: 0 0 1.5rem;
      padding-bottom: 1rem;
      border-bottom: 1px solid var(--border);
      color: var(--muted);
      font-size: 0.9rem;
    }}
    h1 {{ font-size: 1.75rem; margin: 0 0 1rem; line-height: 1.3; }}
    h2 {{ font-size: 1.2rem; margin: 1.75rem 0 0.75rem; color: var(--accent); }}
    h3 {{ font-size: 1.05rem; margin: 1.25rem 0 0.5rem; }}
    p {{ margin: 0.75rem 0; }}
    ul, ol {{ margin: 0.75rem 0; padding-left: 1.4rem; }}
    li {{ margin: 0.35rem 0; }}
    table {{
      width: 100%;
      border-collapse: collapse;
      margin: 1rem 0;
      font-size: 0.9rem;
    }}
    th, td {{
      border: 1px solid var(--border);
      padding: 0.5rem 0.65rem;
      text-align: left;
      vertical-align: top;
    }}
    th {{ background: #f5f2ef; font-weight: 600; }}
    a {{ color: var(--accent); }}
    hr {{ border: none; border-top: 1px solid var(--border); margin: 1.5rem 0; }}
    footer {{
      margin-top: 2rem;
      padding-top: 1rem;
      border-top: 1px solid var(--border);
      font-size: 0.85rem;
      color: var(--muted);
    }}
  </style>
</head>
<body>
  <main>
    <p class="doc-meta">版本 {html.escape(version)} · 生效 {html.escape(effective)}</p>
    {body_html}
    <footer>
      <p>宝宝成长相机 · 合规文档（{html.escape(version)}）</p>
      <p>正式域名：<a href="https://www.babycamera.app/legal/">www.babycamera.app/legal</a></p>
    </footer>
  </main>
</body>
</html>
"""


def generate_one(source: Path) -> Path:
    raw = source.read_text(encoding="utf-8")
    meta, body = parse_frontmatter(raw)
    slug = meta.get("document_id", source.stem)
    body_html = markdown_to_html(body, slug)
    page = build_page(meta, body_html)
    out_dir = OUTPUT_ROOT / slug
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "index.html"
    out_path.write_text(page, encoding="utf-8")
    return out_path


def main() -> int:
    generated: list[Path] = []
    for name in POLICY_FILES:
        source = SOURCE_DIR / name
        if not source.exists():
            print(f"error: missing source {source}", file=sys.stderr)
            return 1
        generated.append(generate_one(source))

    print(f"generated {len(generated)} compliance pages under {OUTPUT_ROOT}")
    for path in generated:
        print(f"  - {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
