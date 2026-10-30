# secrets

One file, `~/.secrets/secrets.yaml`, encrypted with sops + age. Key names are
readable, values are ciphertext; on disk it leaks nothing. `~/.secrets/age.key`
(generated on first install, mode 600) is the one secret that opens it: back it
up in a password manager. `age.pub` is its public half; the shell exports it as
SOPS_AGE_RECIPIENTS so `sops` encrypts to it from any directory. Nothing here is
ever committed anywhere.

    sops ~/.secrets/secrets.yaml                      # edit (decrypts in your editor, re-encrypts on save)
    with-secrets 'psql "$DEV_PG_URL" -c "select 1"'    # run with secrets as env vars
    sops -d --extract '["GITHUB_TOKEN"]' ~/.secrets/secrets.yaml   # one value, only when you must

Names: `<ENV>_<SYSTEM>_<WHAT>` (`PRD_US_<SYSTEM>_<WHAT>`, DEV_GRAFANA_TOKEN);
global ones without a prefix (GITHUB_TOKEN). `manifest.txt` lists the keys the
dotfiles expect; install and doctor report the missing ones. Rule for Claude
sessions: run commands through `with-secrets`, never print a value (the native
deny rules in `modules/claude/settings.owned.json` block reading `~/.secrets`
and `sops` decrypt).
