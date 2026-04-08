---
name: websearch
description: Search the web using Kagi and fetch page contents. Use when you need current information, documentation, or to look up APIs/libraries.
---

# Web Search Skill

Search the web using Kagi and fetch/extract page contents.

## Search

```bash
kagi-search "your query"
```

Returns search results with titles, URLs, and snippets.

### JSON output with quick answer

```bash
kagi-search --json "your query"
```

Returns JSON with:
- `quick_answer.markdown` — AI-generated summary
- `results[].title`, `results[].url`, `results[].snippet`

### Get more results

```bash
kagi-search --json --links 10 "your query"
```

## Fetch a page

```bash
curl -sL "https://example.com" | head -500
```

For cleaner extraction from HTML, pipe through a text extractor or use `curl` with appropriate flags.

## Typical workflow

1. Search: `kagi-search --json "nix flake lock update single input"` — get overview + links
2. Fetch: `curl -sL "<url>"` — get full page content from a promising result
3. Use the information to answer the question or solve the task
