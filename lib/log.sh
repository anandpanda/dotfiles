#!/usr/bin/env bash
# Logging helpers. Colors only when stdout is a terminal.

if [ -t 1 ]; then
  _c_blue=$'\033[34m' _c_green=$'\033[32m' _c_yellow=$'\033[33m' _c_red=$'\033[31m' _c_dim=$'\033[2m' _c_reset=$'\033[0m'
else
  _c_blue="" _c_green="" _c_yellow="" _c_red="" _c_dim="" _c_reset=""
fi

log_info() { printf '%s==>%s %s\n' "$_c_blue" "$_c_reset" "$*"; }
log_ok() { printf '%s ok%s %s\n' "$_c_green" "$_c_reset" "$*"; }
log_warn() { printf '%swarn%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }
log_fail() { printf '%sfail%s %s\n' "$_c_red" "$_c_reset" "$*" >&2; }
log_dry() { printf '%s[dry]%s %s\n' "$_c_dim" "$_c_reset" "$*"; }

die() {
  log_fail "$*"
  exit 1
}

# True when both stdin and stdout are terminals. Guided prompts need both.
is_tty() { [ -t 0 ] && [ -t 1 ]; }
