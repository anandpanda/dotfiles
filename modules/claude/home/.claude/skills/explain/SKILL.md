---
name: explain
description: Use when Anand asks to explain, walk through or teach a concept, mechanism, flow, term or error, or a change (a PR, a branch, his local diff, a colleague's commit), or asks how or why something works. Also when he says "check" about comments on an explainer doc.
---

# Explain

Every explanation is a Claude Doc built from `reference.md`: the change shape when the subject is a change, the concept shape otherwise. How he learns is in `rules/anand.md`; how he writes is in `rules/writing.md`; the shapes, form rules and grounding are in `reference.md`.

## Route the request

| He asks | Output |
|---|---|
| Explain or teach a change or a concept | A new Claude Doc, change or concept shape |
| A doubt about a point in an existing explainer | His comment thread on that doc, answered after he says "check" |
| A one-line fact, not an explanation | A sentence in chat |

## Build the doc

1. Read the subject first: for a change, the diff, its description and the code around it; for a concept, the official docs and where it shows up in his system.
2. Plant the outline (title, byline, one pending block per section of the shape), give him the link, then fill one section per call while he watches.
3. Give the link once and say he can comment on any sentence with "Send to Claude" unticked, then type "check".

## "check"

1. List every thread under the tab's file, not its prose body: comments on a diagram sit under that diagram's widget, and only the file-level query returns them.
2. Answer each unanswered comment of his in its own thread, from this session's context.
3. When a comment shows a point is wrong or unclear, fix the doc text and say so in the thread.
4. When his comments settle a preference about the form (length, a diagram, order), add it to `reference.md`.

## Learning mode

Same doc, filled one section at a time: the frame's map first, then stop and wait for his go before each next section.
