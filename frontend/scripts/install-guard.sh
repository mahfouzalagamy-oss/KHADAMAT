#!/usr/bin/env bash
SELF_DIR=$(dirname "$(readlink -f "$0")")
BIN_NAME=$(basename "$0")

GUARD=""
GUARD_PATH_FILE="${SELF_DIR}/../.guard-path"
if [ -f "$GUARD_PATH_FILE" ]; then
  cand=$(cat "$GUARD_PATH_FILE" 2>/dev/null)
  [ -n "$cand" ] && [ -f "$cand" ] && GUARD="$cand"
fi
if [ -z "$GUARD" ]; then
  for cand in ${CMD_GUARD_FALLBACKS//:/ } \
              /opt/mono-template/mobile/scripts/cmd-guard.js \
              /opt/expo-template/frontend/scripts/cmd-guard.js \
              /app/mobile/scripts/cmd-guard.js \
              /app/frontend/scripts/cmd-guard.js; do
    [ -f "$cand" ] && { GUARD="$cand"; break; }
  done
fi

if [ -z "$GUARD" ] || ! command -v node >/dev/null 2>&1; then
  echo "cmd-guard: guard unavailable (.guard-path missing/stale, no cmd-guard.js); blocking $BIN_NAME" >&2
  exit 1
fi

OUT=$(node "$GUARD" --cmd "$BIN_NAME" --args "$@")
RC=$?
if [ "$RC" -eq 2 ]; then
  NEWARGV=()
  while IFS= read -r line; do
    [ -n "$line" ] && NEWARGV+=("$line")
  done <<EOF
$OUT
EOF
  if [ "${#NEWARGV[@]}" -eq 0 ]; then
    echo "cmd-guard: empty rewrite for $BIN_NAME; blocking" >&2
    exit 1
  fi
  exec "${NEWARGV[@]}"
elif [ "$RC" -ne 0 ]; then
  echo "cmd-guard: blocked $BIN_NAME (guard exit $RC)" >&2
  exit "$RC"
fi

REAL_BIN=""
IFS=':' read -ra DIRS <<<"$PATH"
for dir in "${DIRS[@]}"; do
  if [ "$dir" != "$SELF_DIR" ] && [ -x "$dir/$BIN_NAME" ]; then
    REAL_BIN="$dir/$BIN_NAME"
    break
  fi
done

if [ -z "$REAL_BIN" ]; then
  echo "cmd-guard: real $BIN_NAME not found in PATH" >&2
  exit 1
fi

exec "$REAL_BIN" "$@"