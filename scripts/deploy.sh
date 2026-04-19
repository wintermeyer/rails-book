#!/usr/bin/env bash
# Deploy the Learn Ruby on Rails book (Antora) to bremen2 under
# /var/www/learn-ruby-on-rails-book/releases/<timestamp>/ and
# atomically swap the `current` symlink.
#
# Runs on the `eliph` self-hosted GitHub Actions runner (dedicated
# service `actions.runner.wintermeyer-learn-ruby-on-rails-book.
# bremen2-eliph-rails-book`). Invoked from the actions/checkout
# workdir as `./scripts/deploy.sh`.

set -euo pipefail

# Activate mise so node / npm / npx resolve on the non-interactive
# shell GitHub Actions spawns. `mise activate` only wires the shim
# dir via a precmd hook that never fires in this shell, so prepend
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

# mise install is non-fatal on failure: the runner most likely has
# the pinned Node version already.
if command -v mise >/dev/null 2>&1; then
  mise install || log "WARN: mise install failed, proceeding with current PATH"
fi

log "Fetching latest nav + footer partials from wincon..."
./scripts/fetch-partials.sh

log "Building UI bundle..."
( cd "${REPO_DIR}/ui-bundle" && npm ci --no-audit --no-fund && npm run build )

log "Installing Antora..."
( cd "${REPO_DIR}" && npm ci --no-audit --no-fund )

log "Rendering site..."
( cd "${REPO_DIR}" && npx antora --fetch antora-playbook.yml )

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
