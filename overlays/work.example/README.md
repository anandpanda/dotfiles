# Work overlay (example)

A private repo with this shape, applied by `install.sh work` after the
public modules. Same module rules as the public repo. Typical contents:

    modules/
      git/config/identity.work          # name, email, signing key, url rewrite to github.com-work
      claude-work/home/work/CLAUDE.md   # lands at ~/work/CLAUDE.md
      aws/home/.aws/config              # profile names only, no keys
      kube/Brewfile                     # kubectl, k9s, ...

Never commit secret values here either. Use ~/.secrets.
Create a real one with: just overlay-init ~/personal/dotfiles-work
Host it as a private repo on your own account (it is your config, it follows
you between jobs) and give install the ssh-alias url:
    just install work --overlay git@github.com-personal:you/dotfiles-work.git
