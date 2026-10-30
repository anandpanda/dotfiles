# Phase 8: work layer (public half)

Date: 2026-10-30
Status: approved ("just do it", 2026-10-30)

## Purpose

Let the private overlay add work behaviour to the Claude harness and the git
and gh setup without the public repo knowing any company detail, and stop
"is this work?" being decided by one hardcoded folder name. The overlay half
(work rules text, prod profile names, work folder names) lives in the overlay
repo's own spec.

## Why now

Work machines keep repos in more than one place: `~/work` on the Mac, and a
company-named root that the team's Coder bootstrap hardcodes. Four things
decide work vs personal by checking `~/work` only (git identity includeIf, the
gh context function, commit-hook install, doctor), so a work repo outside it
commits as the personal identity and uses the personal GitHub account.

## 1. Context folders (Anand defines them)

- One place lists the folders for each context, the same on every machine;
  folders that do not exist on a machine are ignored.
- Personal: `~/personal`, owned by the public repo. Work: `~/work`, owned by
  the public repo as the default; the overlay adds its own work folders.
- Everything that asks "work or personal?" reads the lists:
  - git identity: install generates the `includeIf "gitdir:<folder>/"` lines
    for each folder of each context;
  - the gh context function;
  - commit-msg hook install for existing repos, and the doctor scan;
  - the team-skill name-clash check (overlay half).
- Adding a folder is one line in the list and a reinstall.

## 2. Settings fragments

Claude Code reads one user settings file (`~/.claude/settings.json`); there is
no user-level drop-in folder (settings docs). So:

- Any module, public or overlay, may ship a `claude-settings.json` fragment.
- The claude module merges the fragments of every module in the active profile,
  in profile order, with its own owned settings: permission `deny` and `ask`
  lists are combined (no duplicates), other owned keys follow the existing
  merge rules.
- Doctor checks the combined result, so an overlay rule missing from the live
  file is drift, and a public install never removes an overlay rule.
- The public module never names the overlay; a personal-only machine has no
  work fragment and so no work rules.

## 3. Claude Code install

The claude module installs Claude Code with the official native installer when
no `claude` binary exists (found when CI failed: nothing installed it).

## 4. Link record

Install records every link it makes in `~/.config/dotfiles/links`. At the end
of a successful run it removes links from the previous record that this run did
not make, if they still point into the dotfiles repo or the overlay; anything
pointing elsewhere is left alone. The first run (no record) removes nothing.
Doctor reports recorded links that dangle. This replaces per-case prunes.

## Out of scope

Coder workspace setup (next phase), Phase 8's learning-layer idea (folded into
the retro and scout skills; revisit after real use).
