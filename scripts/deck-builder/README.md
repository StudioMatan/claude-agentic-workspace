# deck-builder

A small, generic Python module for building slide decks (`.pptx`) with
[python-pptx](https://python-pptx.readthedocs.io/), styled with a consistent
navy/amber visual system. No hardcoded organization data, no branding
dependency - every string, number, and color comes from a data dict (or a
JSON file) supplied by the caller.

This exists because writing yet another one-off "read some data, make some
slides" script gets tedious fast. I automate my own reporting the same way I
automate everything else: the primitives (title slide, stat row, before/after
flow comparison, pipeline diagram, numbered list, table, closing slide) are
written once and reused across every deck I need to ship, instead of
hand-placing text boxes in PowerPoint each time.

## What it gives you

`DeckBuilder` wraps python-pptx with:

- **Primitives** - `slide()`, `box()`, `txt()`, `stat()`, `slide_title()` -
  the low-level building blocks every composed slide type is made from.
- **Composed slide types** - ready-made functions for common slide shapes:
  - `title_slide()` - cover slide
  - `stat_slide()` - title + row of stat cards + body paragraph
  - `flow_compare_slide()` - two-column numbered step comparison (e.g.
    before/after, manual vs. automated) - built as a structured diagram,
    not a screenshot
  - `pipeline_slide()` - vertical numbered pipeline/architecture flow
  - `numbered_list_slide()` - numbered list of heading + body items
  - `table_slide()` - simple styled table
  - `body_slide()` - title + paragraph
  - `closing_slide()` - cover-style closing slide with links

## Usage

### As a library

```python
from build_deck import DeckBuilder

deck = DeckBuilder()
deck.title_slide("My Project", "One-line subtitle", "footer text")
deck.stat_slide(
    "Title", "Subtitle",
    [("42", "label one"), ("~90%", "label two")],
    "Optional body paragraph under the stats.",
)
deck.flow_compare_slide(
    "Before / after", "What structurally changed",
    "Manual path", ["Step 1", "Step 2", "Step 3"],
    "Automated path", ["Step 1", "Step 2", "Step 3"],
    callout="What moved between the two paths, in one line.",
)
deck.save("out.pptx")
```

### From a JSON spec (CLI)

```bash
python3 build_deck.py --spec deck.json --out deck.pptx
```

`deck.json` shape:

```json
{
  "slides": [
    {"type": "title", "title": "...", "subtitle": "...", "footer": "..."},
    {"type": "stats", "title": "...", "subtitle": "...", "stats": [["42", "label"]], "body": "..."},
    {"type": "flow_compare", "title": "...", "subtitle": "...",
     "left_label": "Manual", "left_steps": ["..."],
     "right_label": "Automated", "right_steps": ["..."],
     "callout": "..."},
    {"type": "pipeline", "title": "...", "subtitle": "...", "steps": [["heading", "desc"]], "caption": "..."},
    {"type": "numbered_list", "title": "...", "subtitle": "...", "items": [["heading", "body"]], "dark": true},
    {"type": "table", "title": "...", "subtitle": "...", "headers": ["A", "B"], "rows": [["1", "2"]]},
    {"type": "body", "title": "...", "subtitle": "...", "body": "..."},
    {"type": "closing", "title": "...", "subtitle": "...", "links": ["..."]}
  ]
}
```

### Demonstration build

Running the script with no arguments builds the actual Falcon → Claude SOAR
overview deck as a worked example:

```bash
python3 build_deck.py
# Saved: ../../flows/falcon-claude-soar/SOAR-Overview.pptx (8 slides)
```

The content for that deck is authored in
[`../../flows/falcon-claude-soar/deck-content.md`](../../flows/falcon-claude-soar/deck-content.md)
and mirrored into the `_build_demo_deck()` function in `build_deck.py`. Edit
the markdown first when changing what the deck says, then keep the Python
dict in sync.

## Requirements

```bash
pip3 install --user python-pptx
```

## Design notes

- Slide canvas is 13.333 x 7.5 in (widescreen 16:9).
- Colors: navy `#1E2761` / amber `#F2A900` / ice `#CADCFC` / ink `#1A1A2E` /
  muted gray `#6B7280` - generic, no organizational branding.
- Fonts: Georgia for headings, Calibri for body, Consolas for monospace/code.
- The before/after comparison is deliberately a structured step-by-step
  diagram (`flow_compare_slide`), not a screenshot of a spreadsheet or
  console - the goal is to show what moved between two processes, not just
  paste a picture of "before" data.
