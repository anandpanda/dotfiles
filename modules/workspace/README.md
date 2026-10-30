# workspace

Lists ~/work and ~/personal in contexts/work and contexts/personal, and
install creates the folders those lists name. Every repo lives under a context folder (the overlay checkout
too: ~/personal/dotfiles-work); git and gh pick the identity from the path.
Any module, public or overlay, may add folders: one per line, `~` allowed,
`#` comments. Install collects them into ~/.config/dotfiles/contexts.
