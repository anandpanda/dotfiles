# ta [name]: attach to (or create) a tmux session, named after the current directory by default.
ta() { tmux new-session -A -s "${1:-${PWD:t}}"; }
