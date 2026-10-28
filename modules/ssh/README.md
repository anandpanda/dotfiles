# ssh

Owns ~/.ssh/conf.d/github.conf with the github.com-personal and
github.com-work host aliases. ~/.ssh/config itself is never replaced:
install only prepends `Include ~/.ssh/conf.d/*.conf` once, so tools
that write into ~/.ssh/config (Coder, VS Code Remote) keep working.
Keys: ~/.ssh/id_ed25519_personal and _work, generated on first install
when a terminal is attached. Add the printed public key to GitHub.
