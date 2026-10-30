---
name: voice-draft
description: Use when drafting any text that will be posted as Anand, such as a PR comment reply, review comment, Slack message, Linear or Notion comment, or email. Writes it short, in his voice, with only his points.
disable-model-invocation: true
---

# Voice draft

Text posted as Anand. It must read like he wrote it.

## Input
- His points, in his words, from this conversation. If a point is yours and he has not agreed to it, leave it out or ask.
- The thread or comment it answers, read in full.

## Draft
- Only his points. Add nothing he did not say: no extra suggestions, no softeners, no thanks he did not give.
- Short: one to three sentences for a reply, a few lines for a message.
- Direct and collaborative: "we should...", "can we...", "I think X because Y".
- Slack: match his language. If his own message was Hinglish, write Hinglish; if English, English.
- No AI slop (`rules/writing.md`), no em-dashes, no headings or bullets in a chat reply unless he uses them.
- No UNVERIFIED claim. Check any fact you include.

## Send
- Show the draft and where it goes (channel, PR, thread).
- A reply to a PR comment: he posts it himself (`rules/building.md`). Give him the final text.
- Anything else: post only on his explicit go for this draft. A paste, "ok" or a question is not a go. After posting, give the link.
