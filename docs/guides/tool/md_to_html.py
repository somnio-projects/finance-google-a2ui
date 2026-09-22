#!/usr/bin/env python3
"""Render the guides into one printable HTML document.

Deliberately dependency-free: this repository pins no Markdown library, and a
generated PDF is not worth adding one for. The subset implemented here is
exactly what `docs/guides/*.md` uses — headings, paragraphs, fenced code
(including ```mermaid, which is left for the browser to draw), GitHub tables,
lists, task lists, block quotes, rules, and the inline set
(`code`, **bold**, *italic*, [links], ![images]).

Mermaid fences become `<div class="mermaid">`; `build_pdf.sh` loads Mermaid
from a pinned CDN and headless Chrome rasterises them before printing.

Usage: md_to_html.py <out.html> <title> <file.md> [<file.md> …]
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# inline
# --------------------------------------------------------------------------

_CODE = re.compile(r"`([^`]+)`")
_IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)\)")
_LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
_BOLD = re.compile(r"\*\*([^*]+)\*\*")
_ITALIC = re.compile(r"(?<![*\w])\*([^*\n]+)\*(?!\*)")
_SLUG_DROP = re.compile(r"[^a-z0-9 -]")


def slug(text: str) -> str:
    """Return a GitHub-style anchor for a heading's text."""
    plain = _CODE.sub(r"\1", text)
    plain = _LINK.sub(r"\1", plain)
    plain = plain.replace("**", "").replace("*", "")
    plain = _SLUG_DROP.sub("", plain.lower().replace("·", ""))
    return re.sub(r"\s+", "-", plain.strip()).strip("-")


def _href(target: str) -> str:
    """Rewrite a cross-guide link so it resolves inside one document."""
    for name in ("feeding-charts.md", "schema-mutations.md"):
        if target.startswith(name):
            rest = target[len(name) :]
            return rest if rest.startswith("#") else f"#doc-{name[:-3]}"
    return target


def inline(text: str) -> str:
    """Render one line of inline Markdown, code spans protected first."""
    spans: list[str] = []

    def stash(match: re.Match[str]) -> str:
        spans.append(f"<code>{html.escape(match.group(1))}</code>")
        return f"\x00{len(spans) - 1}\x00"

    text = _CODE.sub(stash, text)
    text = html.escape(text)
    text = _IMAGE.sub(
        lambda m: f'<img src="{m.group(2)}" alt="{m.group(1)}">', text
    )
    text = _LINK.sub(
        lambda m: f'<a href="{_href(m.group(2))}">{m.group(1)}</a>', text
    )
    text = _BOLD.sub(r"<strong>\1</strong>", text)
    text = _ITALIC.sub(r"<em>\1</em>", text)
    return re.sub(r"\x00(\d+)\x00", lambda m: spans[int(m.group(1))], text)


def split_row(row: str) -> list[str]:
    """Split a table row on the pipes that are not inside a code span."""
    cells: list[str] = []
    cell = ""
    ticks = False
    for char in row.strip().strip("|"):
        if char == "`":
            ticks = not ticks
        if char == "|" and not ticks:
            cells.append(cell)
            cell = ""
        else:
            cell += char
    cells.append(cell)
    return [c.strip() for c in cells]


# --------------------------------------------------------------------------
# blocks
# --------------------------------------------------------------------------

_HEADING = re.compile(r"^(#{1,6})\s+(.*)$")
_FENCE = re.compile(r"^```(\w*)\s*$")
_BULLET = re.compile(r"^\s*[-*]\s+(.*)$")
_NUMBER = re.compile(r"^\s*\d+\.\s+(.*)$")
_TASK = re.compile(r"^\s*[-*]\s+\[([ xX])\]\s+(.*)$")
_ONLY_IMAGE = re.compile(r"^!\[([^\]]*)\]\(([^)\s]+)\)\s*$")


def _table(lines: list[str], start: int, out: list[str]) -> int:
    """Emit a GitHub table starting at ``start``; return the next index."""
    header = split_row(lines[start])
    index = start + 2
    out.append("<table><thead><tr>")
    out.extend(f"<th>{inline(cell)}</th>" for cell in header)
    out.append("</tr></thead><tbody>")
    while index < len(lines) and lines[index].lstrip().startswith("|"):
        out.append("<tr>")
        out.extend(f"<td>{inline(cell)}</td>" for cell in split_row(lines[index]))
        out.append("</tr>")
        index += 1
    out.append("</tbody></table>")
    return index


def _fence(lines: list[str], start: int, out: list[str]) -> int:
    """Emit a fenced block (code, or a Mermaid figure); return next index."""
    language = _FENCE.match(lines[start]).group(1)  # type: ignore[union-attr]
    index = start + 1
    body: list[str] = []
    while index < len(lines) and not lines[index].startswith("```"):
        body.append(lines[index])
        index += 1
    text = "\n".join(body)
    if language == "mermaid":
        out.append(f'<div class="mermaid">{html.escape(text)}</div>')
    else:
        klass = f' class="lang-{language}"' if language else ""
        out.append(f"<pre><code{klass}>{html.escape(text)}</code></pre>")
    return index + 1


def _list(lines: list[str], start: int, out: list[str]) -> int:
    """Emit one list; return the index after it."""
    ordered = bool(_NUMBER.match(lines[start]))
    pattern = _NUMBER if ordered else _BULLET
    tag = "ol" if ordered else "ul"
    index = start
    out.append(f"<{tag}>")
    while index < len(lines):
        task = _TASK.match(lines[index])
        match = pattern.match(lines[index])
        if task and not ordered:
            box = "&#9745;" if task.group(1).lower() == "x" else "&#9744;"
            item = f'<li class="task">{box} {inline(task.group(2))}'
        elif match:
            item = f"<li>{inline(match.group(1))}"
        else:
            break
        index += 1
        # Continuation lines of the same item.
        while (
            index < len(lines)
            and lines[index].strip()
            and lines[index].startswith(("  ", "\t"))
            and not pattern.match(lines[index])
            and not lines[index].lstrip().startswith(("-", "*", "|", "```"))
        ):
            item += " " + inline(lines[index].strip())
            index += 1
        out.append(item + "</li>")
    out.append(f"</{tag}>")
    return index


def _quote(lines: list[str], start: int, out: list[str]) -> int:
    """Emit a block quote; return the index after it."""
    index = start
    body: list[str] = []
    while index < len(lines) and lines[index].startswith(">"):
        body.append(lines[index].lstrip(">").strip())
        index += 1
    out.append(f"<blockquote>{inline(' '.join(body))}</blockquote>")
    return index


def _paragraph(lines: list[str], start: int, out: list[str]) -> int:
    """Emit a paragraph, or a figure when the block is one image."""
    index = start
    body: list[str] = []
    while index < len(lines) and lines[index].strip():
        stop = (
            _HEADING.match(lines[index])
            or _FENCE.match(lines[index])
            or lines[index].lstrip().startswith(("|", ">"))
            or _BULLET.match(lines[index])
            or _NUMBER.match(lines[index])
        )
        if stop and index > start:
            break
        body.append(lines[index].strip())
        index += 1
    text = " ".join(body)
    image = _ONLY_IMAGE.match(text)
    if image:
        out.append(
            f'<figure><img src="{image.group(2)}" alt="{image.group(1)}">'
            f"<figcaption>{inline(image.group(1))}</figcaption></figure>"
        )
    else:
        out.append(f"<p>{inline(text)}</p>")
    return index


def render(markdown: str) -> str:
    """Render one Markdown document to HTML."""
    lines = markdown.replace("\r\n", "\n").split("\n")
    out: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if not line.strip():
            index += 1
        elif re.fullmatch(r"\s*(-{3,}|\*{3,}|_{3,})\s*", line):
            out.append("<hr>")
            index += 1
        elif _FENCE.match(line):
            index = _fence(lines, index, out)
        elif heading := _HEADING.match(line):
            level = len(heading.group(1))
            text = heading.group(2)
            out.append(f'<h{level} id="{slug(text)}">{inline(text)}</h{level}>')
            index += 1
        elif (
            line.lstrip().startswith("|")
            and index + 1 < len(lines)
            and set(lines[index + 1].strip()) <= set("|-: ")
            and "-" in lines[index + 1]
        ):
            index = _table(lines, index, out)
        elif line.startswith(">"):
            index = _quote(lines, index, out)
        elif _BULLET.match(line) or _NUMBER.match(line):
            index = _list(lines, index, out)
        else:
            index = _paragraph(lines, index, out)
    return "\n".join(out)


# --------------------------------------------------------------------------
# document
# --------------------------------------------------------------------------

STYLE = """
@page { size: A4; margin: 16mm 14mm 18mm 14mm; }
* { box-sizing: border-box; }
body { font: 10.5pt/1.55 -apple-system, "Helvetica Neue", Arial, sans-serif;
       color: #14161a; margin: 0; }
h1 { font-size: 22pt; line-height: 1.2; margin: 0 0 .4em; letter-spacing: -.01em; }
h2 { font-size: 14pt; margin: 1.8em 0 .5em; padding-bottom: .25em;
     border-bottom: 1px solid #dfe3e8; break-after: avoid; }
h3 { font-size: 11.5pt; margin: 1.4em 0 .4em; break-after: avoid; }
h4 { font-size: 10.5pt; margin: 1.1em 0 .3em; break-after: avoid; }
p { margin: .55em 0; }
a { color: #2a4fd7; text-decoration: none; }
code { font: 9pt/1.4 "SF Mono", "Menlo", Consolas, monospace;
       background: #f2f4f7; border-radius: 3px; padding: .5pt 3pt;
       word-break: break-word; }
pre { background: #f7f8fa; border: 1px solid #e4e8ee; border-radius: 5px;
      padding: 8pt 10pt; overflow-wrap: anywhere; white-space: pre-wrap;
      margin: .7em 0; }
pre code { background: none; padding: 0; font-size: 8pt; line-height: 1.45; }
table { border-collapse: collapse; width: 100%; margin: .8em 0; font-size: 9pt; }
thead { display: table-header-group; }
tr { break-inside: avoid; }
th, td { border: 1px solid #dfe3e8; padding: 4pt 6pt; text-align: left;
         vertical-align: top; }
th { background: #f2f4f7; font-weight: 600; }
blockquote { margin: .8em 0; padding: 6pt 12pt; border-left: 3px solid #2a4fd7;
             background: #f6f8ff; }
ul, ol { margin: .55em 0; padding-left: 1.4em; }
li { margin: .2em 0; }
li.task { list-style: none; margin-left: -1.1em; }
hr { border: 0; border-top: 1px solid #dfe3e8; margin: 1.6em 0; }
figure { margin: 1em 0; text-align: center; break-inside: avoid; }
figure img { max-width: 100%; max-height: 210mm; border: 1px solid #e4e8ee;
             border-radius: 5px; }
figcaption { font-size: 8.5pt; color: #5b6472; margin-top: 5pt;
             text-align: left; }
.mermaid { break-inside: avoid; margin: 1.1em 0; text-align: center; }
.mermaid svg { max-width: 100%; max-height: 170mm; height: auto; }
.doc { break-before: page; }
.doc:first-of-type { break-before: auto; }
.cover { text-align: left; border-bottom: 2px solid #14161a; padding-bottom: 14pt;
         margin-bottom: 18pt; }
.cover .sub { color: #5b6472; font-size: 11pt; margin: .2em 0 0; }
.cover .meta { color: #5b6472; font-size: 9pt; margin-top: 12pt; }
.toc { font-size: 9.5pt; }
.toc a { color: #14161a; }
"""

MERMAID = """
<script src="MERMAID_SRC"></script>
<script>
  mermaid.initialize({
    startOnLoad: true, theme: 'neutral', securityLevel: 'strict',
    flowchart: { useMaxWidth: false, htmlLabels: true },
    sequence: { useMaxWidth: false, width: 170 }
  });
</script>
"""


def document(title: str, subtitle: str, stamp: str, sections: str, cdn: str) -> str:
    """Wrap the rendered sections in the printable shell."""
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>{html.escape(title)}</title>
<style>{STYLE}</style></head>
<body>
<header class="cover">
  <h1>{html.escape(title)}</h1>
  <p class="sub">{html.escape(subtitle)}</p>
  <p class="meta">{html.escape(stamp)}</p>
</header>
{sections}
{MERMAID.replace("MERMAID_SRC", cdn)}
</body></html>
"""


def main(argv: list[str]) -> int:
    """Render every Markdown file named on the command line into one page."""
    if len(argv) < 4:
        sys.stderr.write(__doc__ or "")
        return 2
    out, title, *sources = argv[1:]
    cdn = "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js"
    parts: list[str] = []
    for source in sources:
        name = Path(source).stem
        body = render(Path(source).read_text(encoding="utf-8"))
        parts.append(f'<section class="doc" id="doc-{name}">{body}</section>')
    Path(out).write_text(
        document(
            title,
            "Somnio x Google A2UI finance showcase — generated from the "
            "Markdown in docs/guides/, which is the source of truth.",
            f"finance-google-a2ui · {Path(out).name}",
            "\n".join(parts),
            cdn,
        ),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
