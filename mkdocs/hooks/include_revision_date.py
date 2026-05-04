"""MkDocs hook: track the included file's git history for include-only pages.

`mkdocs-git-revision-date-localized-plugin` reads git history of the page's
own source file. For pages that only `{% include-markdown "<path>" %}` an
external file (e.g., the changelog stub that pulls the repo-root
CHANGELOG.md), the displayed "last update" date never moves because the
stub itself is rarely touched.

This hook re-runs the date plugin against the included file path and
overrides the page metadata so the footer reflects the included content's
real git history.
"""

from __future__ import annotations

import re
from pathlib import Path

INCLUDE_PATTERN = re.compile(
    r"""\{\%\s*include(?:-markdown)?\s+["']([^"']+)["'][^%]*\%\}"""
)


def _resolve_single_include(markdown: str, source_path: Path) -> Path | None:
    """If `markdown` is a thin wrapper that only includes one file, return its path."""
    stripped = "\n".join(
        line
        for line in markdown.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ).strip()
    matches = INCLUDE_PATTERN.findall(stripped)
    if len(matches) != 1:
        return None
    without_include = INCLUDE_PATTERN.sub("", stripped).strip()
    if without_include:
        return None
    target = (source_path.parent / matches[0]).resolve()
    return target if target.is_file() else None


def _apply_dates(page, plugin, target_path: str, *, is_first_commit: bool) -> None:
    # Mirror plugin.py: page.file.locale (mkdocs-static-i18n) > frontmatter
    # `locale` > plugin config > "en".
    locale = (
        getattr(page.file, "locale", None)
        or page.meta.get("locale")
        or plugin.config.get("locale")
        or "en"
    )
    commit_hash, commit_timestamp = plugin.util.get_git_commit_timestamp(
        path=target_path,
        is_first_commit=is_first_commit,
    )
    if not commit_timestamp:
        return
    formats = plugin.util.get_date_formats_for_timestamp(
        commit_timestamp,
        locale=locale,
        add_spans=True,
    )
    prefix = (
        "git_creation_date_localized"
        if is_first_commit
        else "git_revision_date_localized"
    )
    page.meta[prefix] = formats[plugin.config["type"]]
    page.meta[f"{prefix}_hash"] = commit_hash
    page.meta[f"{prefix}_tag"] = plugin.util.get_tag_name_for_commit(commit_hash)
    for date_type, date_string in formats.items():
        page.meta[f"{prefix}_raw_{date_type}"] = date_string


def on_page_markdown(markdown, *, page, config, **_):
    """After the date plugin runs, replace dates with the included file's history.

    The `markdown` argument is mandated by the MkDocs hook signature; we
    deliberately read the page source from disk so we can detect the
    original `{% include-markdown %}` directive (by this point in the build
    pipeline, the include-markdown plugin has already inlined its content).
    """
    del markdown
    plugin = config.plugins.get("git-revision-date-localized")
    if plugin is None or not plugin.config.get("enabled"):
        return None

    abs_src = page.file.abs_src_path
    if not abs_src:
        return None
    source_path = Path(abs_src)
    # Read the raw source — by the time `markdown` reaches this hook,
    # `include-markdown` has already inlined the included content.
    try:
        raw = source_path.read_text(encoding="utf-8")
    except OSError:
        return None
    target = _resolve_single_include(raw, source_path)
    if target is None:
        return None

    target_path = str(target)
    _apply_dates(page, plugin, target_path, is_first_commit=False)
    if plugin.config.get("enable_creation_date"):
        _apply_dates(page, plugin, target_path, is_first_commit=True)
    return None
