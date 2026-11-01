# workspace

Lists ~/work and ~/personal in contexts/work and contexts/personal, and
install creates the folders those lists name, only for the identities the
profile declares (server-work: work folders only). Every repo lives under a
context folder and git and gh pick the identity from the path. The overlay
checkout is ~/personal/dotfiles-work: a personal repo where the profile has the
personal identity. On a work-only profile (server-work) it has no identity on
purpose: the machine only reads and pulls it (the clone creates ~/personal),
and a commit there is refused by useConfigOnly.
Any module, public or overlay, may add folders: one per line, `~` allowed,
`#` comments. Install collects them into ~/.config/dotfiles/contexts.
