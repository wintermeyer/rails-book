#!/usr/bin/env bash
# Deploy the Learn Ruby on Rails book (Antora) to bremen2 under
# /var/www/learn-ruby-on-rails-book/releases/<timestamp>/ and
# atomically swap the `current` symlink.
#
# Runs on the `eliph` self-hosted GitHub Actions runner dedicated
# to this repo (bremen2-eliph-rails-book). Invoked from the
# actions/checkout workdir as `./scripts/deploy.sh`.

set -euo pipefail

# Activate mise so node / npm / npx resolve on the non-interactive
# shell GitHub Actions spawns. `mise activate` only wires the
# shim dir via a precmd hook that never fires here, so prepend
# the shim dir to PATH directly.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
elif [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi
export PATH="${HOME}/.local/share/mise/shims:${PATH}"

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

if command -v mise >/dev/null 2>&1; then
  mise install || log "WARN: mise install failed, proceeding with current PATH"
fi

log "Fetching latest nav + footer partials from wincon..."
./scripts/fetch-partials.sh

log "Installing Antora..."
npm ci --no-audit --no-fund

log "Rendering site..."
# --fetch refreshes both the content source and the UI bundle
# (wincon-antora-ui/releases/latest/ui-bundle.zip). snapshot:true
# in the playbook tells Antora not to cache across runs.
npx antora --fetch antora-playbook.yml

if [ ! -d "${REPO_DIR}/build/site/book" ]; then
  log "ERROR: expected build/site/book/ not found"
  exit 1
fi

log "Publishing release ${TIMESTAMP}..."
mkdir -p "${RELEASE_DIR}"
cp -a "${REPO_DIR}/build/site/." "${RELEASE_DIR}/"
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
