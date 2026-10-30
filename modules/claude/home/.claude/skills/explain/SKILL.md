---
name: explain
description: Use when Anand asks how or why something works, asks to explain, walk through or teach a concept, file, flow or error, or says "samjha", "how does this work", "what is". Explains from his own files with the diagram type that fits.
---

# Explain

Teach the real thing from his own code. How he learns is in `rules/anand.md`; this is the shape.

## Shape
1. **Map.** The whole thing in three to five lines: the parts, how they connect, where his question sits.
2. **Take one step.** The part he asked about: what it does, the mechanism, and why it is built that way. Use one concrete example from his files or data, cited as file:line.
3. **Diagram.** Pick the type that fits (flow, sequence, state, architecture), as a mermaid block when the surface renders it, else ASCII. Flow for steps and branches, sequence for who calls whom over time, state for lifecycles, architecture for how parts sit together. Text alongside it, balanced: the diagram shows the shape, the text gives the why.
4. **Real terms.** Use the real names and jargon. Define each new term in one line the first time it appears.
5. **Resources.** One to three: the official docs page for the installed version, the canonical book or talk. Open every link before giving it.
6. **Restate.** One or two sentences: the core idea in plain words.

## Depth
- For a concept worth learning deeply, offer an Artifact page (visual, interactive) instead of a long terminal answer. Offer, do not build it unasked.
- In learning mode, stop after each step and wait for his go. Answer only the doubt he raised; no new topics, no quiz.
- Never simplify away the mechanism. Simplify the words.

## Never
- Claims about his code that you did not read this session. Follow `rules/evidence.md`.
- A diagram with no text, or text that only repeats the diagram.
