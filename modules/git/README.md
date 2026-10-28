# git

~/.gitconfig with no identity. includeIf picks identity.personal or
identity.work by directory. identity.work comes from the private overlay.
Each identity rewrites github.com to its SSH alias so clones use the
right key without thinking. user.useConfigOnly makes commits outside
~/work and ~/personal fail loudly.
