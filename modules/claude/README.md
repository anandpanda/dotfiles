# claude

Anand's Claude Code harness, the same on the Mac and on Coder workspaces.
`home/.claude/CLAUDE.md` is the working agreement Claude reads every session;
`home/.claude/rules/*.md` hold the longer forms and load automatically from
`~/.claude/rules/`. Each file is linked into `~/.claude/`. `RESOLVER.md` says
which file owns each rule.

`settings.json` is merged, not linked: install writes only the top-level keys
in `settings.owned.json`, so model, effort and theme stay his. Doctor checks
those keys for drift, that every listed plugin is installed, and that jq and
the claude CLI are present.
