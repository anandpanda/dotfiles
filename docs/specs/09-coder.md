# Phase 9: Coder workspaces

Date: 2026-11-01
Status: approved ("yes", 2026-11-01); experiment run

## Goal

A Coder workspace is managed by the same dotfiles, in the same way, as the
Mac: same profile mechanism, folder-based identity, same harness, same
`dots` commands. No "if Coder" branches; general rules that happen to have
nothing to override on the Mac. Coder is a work-only machine (Anand does no
personal work there).

## Facts (observed on the current workspace, 2026-11-01)

- The team's stable template has Coder's dotfiles module: the workspace's
  "Dotfiles URL" is cloned and `install.sh` runs on every start, with no
  terminal; log in `~/.dotfiles.log`. The current workspace points at a
  colleague's repo, not this one.
- One Coder account SSH key is shared by every workspace. It is on the work
  GitHub account as an Authentication key and, since 2026-11-01, as a Signing
  key, so commits from any workspace verify.
- The template injects git settings: `GIT_SSH_COMMAND` (Coder's key), name and
  email as `GIT_AUTHOR_*` / `GIT_COMMITTER_*` environment variables, and
  global config that rewrites GitHub SSH URLs to HTTPS with Coder's credential
  helper and sets its signing key.
- Coder's HTTPS credential cannot read the private overlay (403). SSH with the
  Coder key can (the work account is a collaborator on the overlay, with push
  access; Anand accepted push over moving the overlay to an organization).
- To verify on the real workspace: processes that do not start from zsh (the
  VS Code server's own git, a non-zsh login shell where chsh is not possible)
  still see the template's `GIT_AUTHOR_*`, `GIT_COMMITTER_*` and
  `GIT_SSH_COMMAND`; the shell rule covers zsh and the dotfiles scripts only.
- Home is a persistent volume; Claude history lives in `~/.claude/projects`
  (about 1,200 transcripts, 65 memory notes on the current workspace).

## Design

1. **Profile on Coder.** `install.sh` with no profile and no remembered one
   picks `server-work` when it runs inside a Coder workspace (Coder sets its
   own environment variables there). Everywhere else the existing rules hold.
2. **Our git config wins, by general rules.**
   - `~/.gitconfig` becomes a plain file per machine whose first line includes
     the repo's git config, so tools that run `git config --global` append to
     the machine's file, never into the repo. Git uses the FIRST matching URL
     rewrite and the LAST value of a single-valued key (experiment a), so our
     rewrites win and appended single values (the template's signing settings)
     win; on Coder those equal ours.
   - `dots doctor` checks the effective result inside a work folder (the URL
     resolves to the work alias, the signing key and email are the expected
     ones), so a template change that diverges is reported, not assumed.
   - Identity comes only from the folder: the shell clears injected
     `GIT_AUTHOR_*` / `GIT_COMMITTER_*` variables.
   - SSH keys come only from the SSH config: the shell clears an injected
     `GIT_SSH_COMMAND`.
   - On the Mac these rules have nothing to clear.
3. **Keys come from the machine.** Each profile declares its identities; the
   SSH config names the key per identity. On Coder the work identity uses the
   Coder account key file Coder provides (nothing to generate); on the Mac
   it uses `id_ed25519_work`. The `server-work` profile has no personal
   identity.
4. **Overlay over SSH** with the work identity's key on Coder.
5. **Moving in.** New workspace from the stable template with this repo as the
   Dotfiles URL; copy `~/.claude/projects` from the old workspace (same paths,
   so sessions resume); audit its memory notes as on the Mac; clone extra team
   repos by hand and `mise install` in each.

## Experiment (run 2026-11-01 on the current workspace)

(a) For the same URL prefix, the first rewrite git reads wins: included last,
the template's HTTPS rewrite won; included first, ours won. (b) Clearing the
injected identity variables restores folder identity. (c) The Coder key is a
plain file (`~/.ssh/git-commit-signing/coder`) and authenticates as the work
account from an SSH config block without `coder gitssh`, so Coder uses the
same mechanism as the Mac: an SSH config entry naming a key file.

## Out of scope

`/retro` (after this phase). Retiring old workspaces is Anand's call.
