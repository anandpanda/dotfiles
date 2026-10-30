# git

~/.gitconfig with no identity: install generates ~/.local/state/git/contexts.inc,
one includeIf per folder in the modules' contexts/ lists, picking identity.personal
or identity.work by directory (identity.work comes from the private overlay). Each identity has
its own SSH signing key; install.sh generates ~/.local/state/git/allowed_signers so
signatures verify locally too. Register each .pub on GitHub as a *signing* key.

Defaults follow "how core git devs configure git": sorted branches, histogram
diffs, autoSetupRemote, prune, rerere, autoStash/autoSquash/updateRefs, zdiff3,
pull.rebase. Pager is delta (Catppuccin); `git dft` runs difftastic.

commit-msg hook (copied into each new/cloned repo via init.templateDir; install also
adds it to existing repos under the context folders that have no hook of their own): first line must be `type(scope): description`.

Aliases: st co sw br ci amend undo wip lg lga pushf (force-with-lease) dft rank.
Shell: `gwt <branch>` new worktree beside the repo, `gwtl`, `gwtr`, `lg` = lazygit.
