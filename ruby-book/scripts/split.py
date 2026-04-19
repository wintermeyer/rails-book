#!/usr/bin/env python3
"""
Split the Rails book's ruby-basics.adoc into one file per top-level
section, writing into ruby-book/modules/ROOT/pages/. Rewrites xrefs
that pointed at ruby-basics.adoc (the single-file version) to the
new per-page target, so the standalone Ruby book renders with
working cross-links.

Invoked from scripts/deploy.sh before `npx antora`. The generated
files under ruby-book/modules/ROOT/pages/ are gitignored.

One source of truth: edits in modules/ROOT/pages/ruby-basics.adoc
flow through to both /rails/book/ruby-basics.html (rendered whole)
and /ruby/book/<chapter>.html (rendered split) on the next deploy.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

SRC = Path("modules/ROOT/pages/ruby-basics.adoc")
DST_DIR = Path("ruby-book/modules/ROOT/pages")
RAILS_BOOK_BASE = "https://wintermeyer-consulting.de/rails/book"

# Maps a top-level `==` section heading to the output filename (without .adoc).
# Ordering here defines the nav order emitted at the bottom.
SECTIONS: list[tuple[str, str]] = [
    ("Ruby 4.0", "ruby-version"),
    ("Basics", "basics"),
    ("Ruby is Object-Oriented", "object-oriented"),
    ("Basic Classes", "basic-classes"),
    ("Variables", "variables"),
    ("Methods Once Again", "methods-once-again"),
    ("if-Condition", "conditionals"),
    ("Loops", "loops"),
    ("Arrays and Hashes", "collections"),
    ("Range", "ranges"),
]


def main() -> int:
    src = SRC.read_text()
    DST_DIR.mkdir(parents=True, exist_ok=True)

    # Strip existing output so a removed section in ruby-basics.adoc
    # doesn't leave a stale file behind.
    for stale in DST_DIR.glob("*.adoc"):
        stale.unlink()

    header, sections = slice_sections(src)

    # Inventory anchors per output slug so we can rewrite xrefs.
    anchors: dict[str, str] = {}
    for title, body in sections:
        slug = slug_of(title)
        for match in re.finditer(r"^\[\[([^\]]+)\]\]", body, re.MULTILINE):
            anchors[match.group(1)] = slug

    # Emit the landing page from the preamble.
    index_body = rewrite_refs(header.strip(), anchors, current_slug=None)
    index_body = index_body.lstrip("\n")
    index_body = re.sub(r"^\[\[ruby-basics\]\]\n", "", index_body)
    index_body = re.sub(r"^= Ruby Introduction", "= Welcome", index_body, count=1)
    (DST_DIR / "index.adoc").write_text(
        index_body + "\n\n"
        "Pick a chapter from the sidebar. The material here is lifted from the "
        "Ruby Introduction chapter in the "
        f"link:{RAILS_BOOK_BASE}/ruby-basics.html[_Learn Ruby on Rails_ book], "
        "split page-per-section so each topic has its own URL.\n"
    )

    # Emit each section.
    for title, body in sections:
        slug = slug_of(title)
        rewritten = rewrite_refs(body, anchors, current_slug=slug)
        # Down-shift == to = so Antora treats the section heading as the page h1.
        rewritten = re.sub(r"^== ", "= ", rewritten, count=1, flags=re.MULTILINE)
        # Then shift all other headings down (=== -> ==, ==== -> ===, …).
        rewritten = re.sub(
            r"^(={3,6}) ",
            lambda m: "=" * (len(m.group(1)) - 1) + " ",
            rewritten,
            flags=re.MULTILINE,
        )
        (DST_DIR / f"{slug}.adoc").write_text(rewritten)

    print(f"split {len(sections)} chapters into {DST_DIR}/")
    return 0


def slice_sections(src: str) -> tuple[str, list[tuple[str, str]]]:
    lines = src.splitlines(keepends=True)

    boundaries: list[int] = []
    for i, line in enumerate(lines):
        if line.startswith("== "):
            boundaries.append(i)

    header = "".join(lines[: boundaries[0]])
    # Walk sections, strip anchor-only lines that directly precede the ==
    # (we treat those as belonging to the section).
    sections: list[tuple[str, str]] = []
    for j, start in enumerate(boundaries):
        end = boundaries[j + 1] if j + 1 < len(boundaries) else len(lines)
        # If the line just before `start` is a `[[id]]`, pull it in as
        # part of this section (anchor the page on that id).
        if start > 0 and re.match(r"^\[\[[^\]]+\]\]\s*$", lines[start - 1]):
            body = "".join(lines[start - 1 : end])
        else:
            body = "".join(lines[start:end])
        title = lines[start][3:].strip()
        sections.append((title, body))

    return header, sections


def slug_of(title: str) -> str:
    declared = dict(SECTIONS)
    if title in declared:
        return declared[title]
    raise SystemExit(
        f"No slug mapping for section {title!r}. Add it to SECTIONS at the top "
        f"of {__file__}."
    )


# Two kinds of xref need rewriting in the split output:
#
# 1. xref:ruby-basics.adoc#<anchor>[label] — same-file xref from the
#    pre-split world. Becomes same-page (<<anchor,label>>) if the
#    anchor lives in this output file, otherwise xref:<slug>.adoc#
#    <anchor>[label].
# 2. xref:<otherchapter>.adoc#<anchor>[label] — xref to another
#    Rails-book chapter (e.g. installing.adoc) that has no presence
#    in the Ruby mini-book. Convert to an absolute link back to the
#    Rails book so the link still resolves.
XREF_RE = re.compile(r"xref:([a-zA-Z0-9_-]+)\.adoc#([a-zA-Z0-9_-]+)\[([^\]]*)\]")


def rewrite_refs(text: str, anchors: dict[str, str], current_slug: str | None) -> str:
    def replace(match: re.Match[str]) -> str:
        chapter, anchor, label = match.group(1), match.group(2), match.group(3)
        if chapter != "ruby-basics":
            # Points at a Rails-book-only chapter. The Ruby mini-book
            # doesn't own that content; link to the Rails book copy.
            return f"link:{RAILS_BOOK_BASE}/{chapter}.html#{anchor}[{label}]"

        target_slug = anchors.get(anchor)
        if target_slug is None:
            # Anchor doesn't exist in the split — fall back to the
            # single-file Rails book rendering.
            return f"link:{RAILS_BOOK_BASE}/ruby-basics.html#{anchor}[{label}]"
        if target_slug == current_slug:
            return f"<<{anchor},{label}>>"
        return f"xref:{target_slug}.adoc#{anchor}[{label}]"

    return XREF_RE.sub(replace, text)


if __name__ == "__main__":
    sys.exit(main())
