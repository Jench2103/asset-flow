# mkdocs/CLAUDE.md

## Overview

Documentation site for AssetFlow, built with [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/). Config: `mkdocs.yml` (project root). Content: `mkdocs/en/`. See `mkdocs/README.md` for setup instructions.

## Commands

```bash
uv run mkdocs serve          # Local dev server at http://127.0.0.1:8000
uv run mkdocs build          # Build static site to site/
uv run mkdocs gh-deploy      # Deploy to GitHub Pages
```

## Site Structure

Two navbar tabs: **Home** (project landing page) and **User Guide** (all user-facing docs). Each tab has its own sidebar. Future tabs (e.g., Developer Guide) can be added as top-level nav entries in `mkdocs.yml`.

## i18n

Uses `mkdocs-static-i18n` with folder-based layout. English: `mkdocs/en/`. Chinese (Taiwanese): `mkdocs/zh-TW/` (mirrors `en/` structure). Screenshots in `mkdocs/assets/images/` are shared across languages.

To add a language: create the folder, add the locale to `mkdocs.yml > plugins > i18n > languages`.

## Images

- Screenshots stored in `mkdocs/assets/images/` and tracked by **Git LFS** (configured in `.gitattributes`)
- Contributors need `git lfs install` before cloning
- Reference images from content pages with relative paths (e.g., `../../assets/images/app-overview.png` from `guide/` pages)

## Writing Conventions

- **Audience**: End users, not developers. Friendly, clear tone.
- **Em-dashes**: Avoid in repetitive patterns (e.g., "See also" link lists). Use colons instead: `- [Page](link.md): Description`. Em-dashes in prose are fine when they sound natural.
- **Ordered lists**: Use `1.` for all items (same as project-wide convention).
- **Keyboard shortcuts**: Use `pymdownx.keys` syntax: `++cmd+n++`, `++cmd+comma++`.
- **Admonitions**: Use `!!! tip`, `!!! note`, `!!! warning` for callouts. Leave a blank line after the `!!!` directive.
- **Settings navigation**: Settings is a macOS settings window (++cmd+comma++), not in the sidebar. Write "Open **Settings** (++cmd+comma++)" not "Go to Settings in the sidebar."
- **Cross-references**: Every page ends with a "See also" section linking to related pages.
- **No duplication**: Cash flows page covers workflow; performance metrics covers the math. Charts are covered inline in each feature page, not as a standalone page. Import CSV covers workflow; reference/csv-format covers the spec.

## Required Extensions

Grid cards on the home page require `md_in_html`. Material icons (`:material-camera:`) require `pymdownx.emoji`. Both are configured in `mkdocs.yml`. If adding new markdown features, ensure the required extension is listed.

## Formatting

MkDocs content uses a separate `mdformat` pre-commit hook (`mdformat-mkdocs` + `mdformat-front-matters` + `mdformat-simple-breaks`) instead of the project-wide `mdformat-gfm`. This preserves Material for MkDocs syntax (frontmatter, admonitions, grid card `---` separators) that standard mdformat would break.

## Verifying Changes

```bash
uv run mkdocs build 2>&1 | grep -E "WARNING|ERROR"
```

Warnings about missing images are expected if screenshots haven't been added yet. Warnings about broken links or missing pages indicate real issues.
