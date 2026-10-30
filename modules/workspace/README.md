# workspace

Creates ~/work and ~/personal and lists them in contexts/work and
contexts/personal. Every repo lives under a context folder (the overlay checkout
too: ~/personal/dotfiles-work); git and gh pick the identity from the path.
Any module, public or overlay, may add folders: one per line, `~` allowed,
`#` comments. Install collects them into ~/.config/dotfiles/contexts.
