#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
GUARD="$SCRIPT_DIR/cmd-guard.js"
SHIM_SRC="$SCRIPT_DIR/install-guard.sh"
BIN_DIR=${INSTALL_GUARD_BIN:-/opt/install-guard/bin}
MASTER="$BIN_DIR/.install-guard.sh"

[ -f "$GUARD" ] || { echo "sync-shims: cmd-guard.js not found at $GUARD; refusing to sync" >&2; exit 1; }

if ! CMD_LIST=$(node "$GUARD" --list-commands); then
  echo "sync-shims: 'node cmd-guard.js --list-commands' failed; refusing to drop shims" >&2; exit 1
fi
CMDS=($CMD_LIST)
[ "${#CMDS[@]}" -gt 0 ] || { echo "sync-shims: empty command list; refusing to drop shims" >&2; exit 1; }

mkdir -p "$BIN_DIR"
install -m 0755 "$SHIM_SRC" "$MASTER"

GUARD_PATH_DIR=$(dirname "$BIN_DIR"); mkdir -p "$GUARD_PATH_DIR"
printf '%s' "$GUARD" > "$GUARD_PATH_DIR/.guard-path"

for name in "${CMDS[@]}"; do ln -sf "$MASTER" "$BIN_DIR/$name"; done

for f in "$BIN_DIR"/*; do
  [ -L "$f" ] && [ "$(readlink "$f")" = "$MASTER" ] || continue
  case " ${CMDS[*]} " in *" $(basename "$f") "*) : ;; *) rm -f "$f" ;; esac
done