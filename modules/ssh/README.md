# ssh

Owns ~/.ssh/conf.d/github.conf with the github.com-personal and
github.com-work host aliases. ~/.ssh/config itself is never replaced:
install only prepends `Include ~/.ssh/conf.d/*.conf` once, so tools
that write into ~/.ssh/config (Coder, VS Code Remote) keep working.
Each alias lists its candidate key files in order and ssh skips missing ones:
the generated ~/.ssh/id_ed25519_personal or _work first, then a Coder
workspace's account key ~/.ssh/git-commit-signing/coder. Install generates a
key for an identity only when none of its candidates exists and a terminal is
attached; add the printed public key to GitHub. Which identities a machine has
comes from its profile (`identities = [...]`); server-work has only work.
