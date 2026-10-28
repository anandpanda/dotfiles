# secrets

~/.secrets/<name> files, mode 700 directory, never committed anywhere.
manifest.txt lists what is expected; install and doctor report gaps.
Projects read values via direnv (.envrc: export X="$(cat ~/.secrets/x)").
