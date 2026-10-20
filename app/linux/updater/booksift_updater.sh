#!/bin/sh
# BookSift Linux update helper. The main process exits before replacement.
set -eu

ARCHIVE="${1:?archive missing}"
BUNDLE="${2:?bundle missing}"
APP_PID="${3:?pid missing}"
EXE_NAME="booksift"
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/booksift-update.XXXXXX")"
STAGING="$WORK_ROOT/staging"
BACKUP="$WORK_ROOT/backup"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/BooksSift"
LOG_FILE="$LOG_DIR/update.log"

mkdir -p "$STAGING" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >>"$LOG_FILE"
}

cleanup() {
  rm -rf "$WORK_ROOT"
}

trap cleanup EXIT HUP INT TERM

for _ in $(seq 1 120); do
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    break
  fi
  sleep 0.25
done
if kill -0 "$APP_PID" 2>/dev/null; then
  log "BookSift did not exit before update"
  exit 1
fi

if ! tar -xzf "$ARCHIVE" -C "$STAGING"; then
  log "failed to extract $ARCHIVE"
  exit 1
fi

SOURCE="$STAGING"
if [ ! -f "$SOURCE/$EXE_NAME" ]; then
  for candidate in "$STAGING"/*; do
    if [ -f "$candidate/$EXE_NAME" ]; then
      SOURCE="$candidate"
      break
    fi
  done
fi
if [ ! -x "$SOURCE/$EXE_NAME" ]; then
  log "archive does not contain executable $EXE_NAME"
  exit 1
fi

if [ -d "$BUNDLE" ]; then
  if ! mv "$BUNDLE" "$BACKUP"; then
    log "failed to back up $BUNDLE"
    exit 1
  fi
  BUNDLE_MOVED=1
else
  BUNDLE_MOVED=0
fi
if ! mv "$SOURCE" "$BUNDLE"; then
  if [ "$BUNDLE_MOVED" -eq 1 ]; then
    if [ -d "$BUNDLE" ]; then
      rm -rf "$BUNDLE"
    fi
    mv "$BACKUP" "$BUNDLE"
  fi
  log "failed to move staged update into $BUNDLE"
  exit 1
fi

chmod +x "$BUNDLE/$EXE_NAME"
if [ -f "$BUNDLE/data/update/booksift_updater.sh" ]; then
  chmod +x "$BUNDLE/data/update/booksift_updater.sh"
fi
"$BUNDLE/$EXE_NAME" >/dev/null 2>&1 &
log "replaced $BUNDLE"
exit 0
