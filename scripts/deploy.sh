#!/usr/bin/env bash
# Deploy the Learn Ruby on Rails book to bremen2 under
# /var/www/learn-ruby-on-rails-book/releases/<timestamp>/ and
# atomically swap the `current` symlink.
#
# Runs on the `eliph` self-hosted GitHub Actions runner (same runner
# that deploys elixir-phoenix-ash). Invoked from the actions/checkout
# workdir as `./scripts/deploy.sh`.
#
# Tooling is provided by mise: Ruby for asciidoctor, Node for the
# Tailwind chrome.css compile. Versions pinned in `.tool-versions`.

set -euo pipefail

# Activate mise so ruby / bundle / node / npm / npx resolve on the
# non-interactive shell GitHub Actions spawns.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
elif [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi

APP_DIR="/var/www/learn-ruby-on-rails-book"
RELEASES_DIR="${APP_DIR}/releases"
CURRENT_LINK="${APP_DIR}/current"
SHARED_DIR="${APP_DIR}/shared"
LOCK_FILE="${SHARED_DIR}/.deploy.lock"
KEEP_RELEASES=5
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="${RELEASES_DIR}/${TIMESTAMP}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

mkdir -p "${SHARED_DIR}"
exec 9>"${LOCK_FILE}"
flock -n 9 || { log "ERROR: another deploy is running"; exit 1; }

REPO_DIR="$(pwd)"
log "Repo: ${REPO_DIR}"

# Let mise install the versions pinned in .tool-versions if they are
# not already present on the runner. A no-op on subsequent deploys.
# Non-fatal on failure — maybe the runner has the tools already or
# the registry is flaky; we'll find out soon enough at the next step.
if command -v mise >/dev/null 2>&1; then
  mise install || log "WARN: mise install failed, proceeding with current PATH"
fi

log "Fetching latest nav + footer partials from wincon..."
./scripts/fetch-partials.sh

log "Installing Ruby gems..."
bundle config set --local path 'vendor/bundle'
bundle install --quiet

log "Installing Node packages..."
npm ci --no-audit --no-fund

log "Building HTML..."
bundle exec rake html

if [ ! -f "${REPO_DIR}/output/learn-ruby-on-rails.html" ]; then
  log "ERROR: expected output/learn-ruby-on-rails.html not found"
  exit 1
fi

log "Publishing release ${TIMESTAMP}..."
mkdir -p "${RELEASE_DIR}"
cp -a "${REPO_DIR}/output/." "${RELEASE_DIR}/"
chmod -R a+rX "${RELEASE_DIR}"

log "Atomic swap..."
ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}.new"
mv -fT "${CURRENT_LINK}.new" "${CURRENT_LINK}"

log "Pruning old releases (keeping last ${KEEP_RELEASES})..."
mapfile -t _old < <(
  find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort | head -n "-${KEEP_RELEASES}"
)
for r in "${_old[@]}"; do
  [ -n "${r}" ] && rm -rf "${RELEASES_DIR:?}/${r}"
done

log "Deploy complete: ${TIMESTAMP}"
log "  Active: ${CURRENT_LINK} -> $(readlink -f "${CURRENT_LINK}")"
