# Explainer reference

## Grounding (both shapes)

- Explain at the level of ideas: the problem, the concepts, the engineering, the design and how parts connect.
- No code blocks, no file:line references, no walk through functions. The doc reads without opening the repo.
- The running example comes from his real system, named in words.

## Change shape

A change (PR, branch, local diff) is a proposal. The doc teaches it and judges whether its design is the ideal, principled one. Defects, risk and rollout are `/review-change` work and stay out.

Frame
1. **In one paragraph**: what changes and why.
2. **The problem**: one real case.
3. **The map**: the parts and how they connect, before and after, as one diagram.
4. **The approach**: the overall design, and whether it is the ideal one. When a better approach exists, what it is and why.

Part N, one per part of the map, in map order
- **What it's for**: its slice of the problem.
- **How it works**: concepts introduced here at first use; the running example passes through. A failure-handling choice that is a design decision is explained here, once.
- **Is this the ideal?**: the principled design for this part; the change's choice against the better one, if any.

Closing
5. **How the parts fit**: the end-to-end flows across parts. A one-part change has no closing; its frame and part merge.

## Concept shape

Frame
1. **In one paragraph**: what it is and why it exists.
2. **The problem it solves**: one real case, life without it.
3. **The map**: its parts and how they connect.

Part N
- **What it's for**.
- **How it works**: concepts at first use; the running example passes through.
- **Why it's built this way**: the design choice and what it trades away against the obvious alternative.

Closing
4. **How the parts fit**: end to end.
5. **Go deeper**: one to three links (official docs, the canonical book or talk), each opened before giving it.

## Form

1. Every section opens with its point. No "in this section we will".
2. Paragraphs of at most three full sentences. Bullets only for truly parallel items.
3. A new term is bold at first use and defined in the same sentence; later parts refer back in a few words.
4. At most one diagram per part, right after the lead. Its title states the point; about seven boxes at most; only what changed is highlighted.
5. The diagram type follows the idea: layers for parts that fit together, flow for steps and decisions, sequence for who calls whom over time, state for a lifecycle, before and after in the same layout, a comparison table for options.
6. One running example with a real-looking actor, carried through every part.
7. "Is this the ideal?" and "Why it's built this way" open with a one-line verdict ("Principled" or "A cleaner design exists"), then why. A comparison table only for two or more options, criteria as rows.
8. Spacious: a part fits about one screen, bullets nest one level at most, each part has its heading.
9. Objective tone: no marketing words, no praise of the change.
10. Section and part numbers only. Comments anchor to the words he highlights, so points are not numbered.

## Why this shape

Research and sources: `~/personal/reviews/explainer-template/research.md`. In short: the Rust RFC and Google design-doc templates for problem, approach and alternatives; advance organizers (map first), concrete before abstract and terms at first use from learning science; Mayer's multimedia principles for diagram placement and density.
