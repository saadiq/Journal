#!/usr/bin/env bash
# Local Ghost preview — runs ghost:5-alpine at :2368 with this theme mounted.
# See CLAUDE.md → "Local preview" for the full story.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CONTAINER="${CONTAINER:-journal-preview}"
IMAGE="${IMAGE:-ghost:5-alpine}"
PORT="${PORT:-2368}"
PROD_HOST="${PROD_HOST:-saadiq@167.71.169.225}"

# Bind-mount targets — all under /tmp so they're easy to nuke individually.
THEME_DIR="${THEME_DIR:-/tmp/journal-theme-preview}"
IMAGES_DIR="${IMAGES_DIR:-/tmp/journal-preview-images}"
DATA_DIR="${DATA_DIR:-/tmp/journal-preview-data-host}"

# First-run admin seed — not secret, lives in a local-only sqlite DB.
ADMIN_NAME="Preview"
ADMIN_EMAIL="preview@example.com"
ADMIN_PASSWORD="PreviewPass1234"
BLOG_TITLE="field notes"

RSYNC_EXCLUDES=(
  --exclude=node_modules
  --exclude=dist
  --exclude=.git
  --exclude=.DS_Store
  --exclude=.superpowers
  --exclude=.claude
  --exclude=CLAUDE.md
  --exclude=.gitignore
  --exclude=yarn-error.log
  --exclude=scripts
)

stage_theme() {
  mkdir -p "$THEME_DIR"
  rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$REPO_ROOT/" "$THEME_DIR/"
}

wait_ready() {
  local deadline=$((SECONDS + 120))
  until curl -sf -o /dev/null "http://localhost:${PORT}/ghost/api/admin/site/" 2>/dev/null; do
    if [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null)" = "exited" ]; then
      echo "ghost container exited — last logs:" >&2
      docker logs --tail 20 "$CONTAINER" >&2
      exit 1
    fi
    if [ $SECONDS -ge $deadline ]; then
      echo "timed out waiting for ghost to boot" >&2; exit 1
    fi
    sleep 2
  done
}

first_run_setup() {
  local cookies
  cookies="$(mktemp)"
  trap 'rm -f "$cookies"' RETURN

  curl -sfc "$cookies" -X POST "http://localhost:${PORT}/ghost/api/admin/authentication/setup/" \
    -H "Content-Type: application/json" -H "Origin: http://localhost:${PORT}" \
    -d "{\"setup\":[{\"name\":\"${ADMIN_NAME}\",\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\",\"blogTitle\":\"${BLOG_TITLE}\"}]}" \
    -o /dev/null

  curl -sfc "$cookies" -b "$cookies" -X POST "http://localhost:${PORT}/ghost/api/admin/session/" \
    -H "Content-Type: application/json" -H "Origin: http://localhost:${PORT}" \
    -d "{\"username\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" \
    -o /dev/null

  curl -sfb "$cookies" -X PUT "http://localhost:${PORT}/ghost/api/admin/themes/journal-field-notes/activate/" \
    -H "Origin: http://localhost:${PORT}" -o /dev/null
}

cmd="${1:-up}"

case "$cmd" in
  up)
    stage_theme
    mkdir -p "$IMAGES_DIR" "$DATA_DIR"

    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker run -d \
      --name "$CONTAINER" \
      -p "${PORT}:2368" \
      -e NODE_ENV=development \
      -e url="http://localhost:${PORT}" \
      -e security__staffDeviceVerification=false \
      -e database__client=sqlite3 \
      -e database__connection__filename=/var/lib/ghost/content/data/ghost.db \
      -e database__useNullAsDefault=true \
      -v "$THEME_DIR:/var/lib/ghost/content/themes/journal-field-notes" \
      -v "$IMAGES_DIR:/var/lib/ghost/content/images" \
      -v "$DATA_DIR:/var/lib/ghost/content/data" \
      "$IMAGE" >/dev/null

    wait_ready

    # Run setup only if the DB is fresh (status:false).
    if curl -s "http://localhost:${PORT}/ghost/api/admin/authentication/setup/" | grep -q '"status":false'; then
      echo "first run — seeding admin + activating theme..."
      first_run_setup
    fi

    cat <<EOF

Ghost preview ready:
  Front:  http://localhost:${PORT}/
  Admin:  http://localhost:${PORT}/ghost/
  Login:  ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}

EOF
    ;;

  down)
    docker rm -f "$CONTAINER" >/dev/null 2>&1 && echo "stopped $CONTAINER" || echo "$CONTAINER not running"
    ;;

  sync-theme)
    stage_theme
    echo "theme staged at $THEME_DIR — reload any page to pick up changes"
    ;;

  sync-images)
    mkdir -p "$IMAGES_DIR"
    rsync -a --rsync-path='sudo rsync' \
      "${PROD_HOST}:/var/www/ghost/content/images/" "$IMAGES_DIR/"
    echo "images synced to $IMAGES_DIR"
    ;;

  reset)
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    rm -rf "$DATA_DIR"
    echo "container + DB wiped. Run 'up' to start fresh."
    ;;

  *)
    cat <<EOF
usage: $(basename "$0") <command>

  up            start/restart Ghost at :${PORT} (first run seeds admin + activates theme)
  down          stop + remove container (DB, images, theme stay on disk)
  sync-theme    re-stage theme after editing source + running 'bun run build'
  sync-images   rsync prod content/images/ to ${IMAGES_DIR} (~476MB first time)
  reset         nuke container + local DB (images survive)

Paths (override with env vars):
  THEME_DIR=${THEME_DIR}
  IMAGES_DIR=${IMAGES_DIR}
  DATA_DIR=${DATA_DIR}
EOF
    exit 1
    ;;
esac
