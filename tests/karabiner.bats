load helper
K="modules/karabiner"
setup() { setup_home; for f in log os link module; do source "$DOTFILES_DIR/lib/$f.sh"; done; }
teardown() { teardown_home; }

@test "karabiner.json is valid and maps caps lock to escape/hyper" {
  python3 - "$DOTFILES_DIR/$K/home/.config/karabiner/karabiner.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
p = d["profiles"][0]; assert p["selected"] is True
m = p["complex_modifications"]["rules"][0]["manipulators"][0]
assert m["from"]["key_code"] == "caps_lock"
assert m["to_if_alone"][0]["key_code"] == "escape"
assert m["to"][0]["key_code"] == "left_shift" and set(m["to"][0]["modifiers"]) == {"left_control", "left_option", "left_command"}
PY
  grep -q 'os = "macos"' "$DOTFILES_DIR/$K/module.toml"
}

@test "karabiner.json round-trips through Karabiner's own formatting unchanged" {
  f="$DOTFILES_DIR/$K/home/.config/karabiner/karabiner.json"
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); out=json.dumps(d, indent=4, ensure_ascii=False)+'\n'; sys.exit(0 if out==open(sys.argv[1]).read() else 1)" "$f"
}

@test "doctor warns on drift and is quiet when the live file matches" {
  module_apply "$DOTFILES_DIR/$K" >/dev/null
  run bash "$DOTFILES_DIR/$K/doctor.sh"; [ "$status" -eq 0 ]; [[ "$output" != *changed* ]]
  cp "$DOTFILES_DIR/$K/home/.config/karabiner/karabiner.json" "$HOME/live.json"
  command rm "$HOME/.config/karabiner/karabiner.json"; python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d['profiles'][0]['name']='edited'; json.dump(d, open(sys.argv[2],'w'), indent=4)" "$HOME/live.json" "$HOME/.config/karabiner/karabiner.json"
  run bash "$DOTFILES_DIR/$K/doctor.sh"; [ "$status" -eq 0 ]; [[ "$output" == *"changed outside the repo"* ]]
}
