#!/bin/bash
# Export new photos from Apple Photos into smart-gallery's imports/incoming folder.
# Meant to run every few minutes from launchd; safe to run by hand too.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state"
STAGING_DIR="$STATE_DIR/staging"
EXPORT_DB="$STATE_DIR/export.db"
SINCE_FILE="$STATE_DIR/since"
INCOMING_DIR="$(dirname "$SCRIPT_DIR")/imports/incoming"
OSXPHOTOS="$SCRIPT_DIR/.venv/bin/osxphotos"

mkdir -p "$STAGING_DIR" "$INCOMING_DIR"

# Only sync photos added after the first run, not the whole existing library.
if [ ! -f "$SINCE_FILE" ]; then
  date +%Y-%m-%dT%H:%M:%S > "$SINCE_FILE"
fi

echo "[$(date)] Syncing photos added after $(cat "$SINCE_FILE")"

# Export into a staging folder first, so the backend never sees a half-written file.
"$OSXPHOTOS" export "$STAGING_DIR" \
  --exportdb "$EXPORT_DB" \
  --update --only-new \
  --added-after "$(cat "$SINCE_FILE")" \
  --only-photos --skip-live --skip-original-if-edited \
  --download-missing \
  --convert-to-jpeg \
  --filename "{uuid}"

# Moving within the same disk is instant, so each file appears in incoming fully written.
moved=0
for file in "$STAGING_DIR"/*.jpeg; do
  [ -e "$file" ] || continue
  mv "$file" "$INCOMING_DIR/"
  moved=$((moved + 1))
done

echo "[$(date)] Moved $moved photo(s) to $INCOMING_DIR"
