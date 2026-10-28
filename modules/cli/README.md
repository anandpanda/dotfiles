# cli

The modern command-line stack, one Brewfile. Configs for bat, btop and
yazi live under home/.config/<tool> because those tools read their own
XDG dirs, not ~/.config/cli. Themes are vendored (see THEMES.md).

Day to day: `ls`/`ll`/`lt` are eza, `cat` is bat, Ctrl-T fuzzy-finds a
file with preview, Alt-C fuzzy-cds, `z <part of a path>` jumps, `yazi`
browses, `tldr <cmd>` for quick examples.
