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

RAILS_APP_DIR="/var/www/learn-ruby-on-rails-book"
RUBY_APP_DIR="/var/www/ruby-book"
KEEP_RELEASES=5
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

RAILS_RELEASE_DIR="${RAILS_APP_DIR}/releases/${TIMESTAMP}"
RUBY_RELEASE_DIR="${RUBY_APP_DIR}/releases/${TIMESTAMP}"
LOCK_FILE="${RAILS_APP_DIR}/shared/.deploy.lock"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

mkdir -p "${RAILS_APP_DIR}/shared"
exec 9>"${LOCK_FILE}"
flock -n 9 || { log "ERROR: another deploy is running"; exit 1; }

REPO_DIR="$(pwd)"
log "Repo: ${REPO_DIR}"

publish_release() {
  local app_dir="$1"
  local release_dir="$2"
  local source_dir="$3"

  log "Publishing ${release_dir}..."
  mkdir -p "${release_dir}"
  cp -a "${source_dir}/." "${release_dir}/"
  chmod -R a+rX "${release_dir}"

  local current_link="${app_dir}/current"
  log "Atomic swap ${current_link} -> ${release_dir}"
  ln -sfn "${release_dir}" "${current_link}.new"
  mv -fT "${current_link}.new" "${current_link}"

  log "Pruning ${app_dir}/releases (keeping last ${KEEP_RELEASES})..."
  mapfile -t _old < <(
    find "${app_dir}/releases" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
      | sort | head -n "-${KEEP_RELEASES}"
  )
  for r in "${_old[@]}"; do
    [ -n "${r}" ] && rm -rf "${app_dir}/releases/${r:?}"
  done
}

# mise install is non-fatal on failure: the runner most likely has
# the pinned Node version already.
if command -v mise >/dev/null 2>&1; then
  mise install || log "WARN: mise install failed, proceeding with current PATH"
fi

log "Fetching latest nav + footer partials from wincon..."
./scripts/fetch-partials.sh

log "Splitting ruby-basics.adoc into ruby-book/modules/ROOT/pages/..."
python3 ruby-book/scripts/split.py

log "Installing Antora..."
( cd "${REPO_DIR}" && npm ci --no-audit --no-fund )

log "Rendering Rails book..."
# --fetch refreshes both the content source and the UI bundle
# (wincon-antora-ui/releases/latest/ui-bundle.zip). snapshot:true
# in the playbook tells Antora not to cache across runs.
( cd "${REPO_DIR}" && npx antora --fetch antora-playbook.yml )

if [ ! -d "${REPO_DIR}/build/site/book" ]; then
  log "ERROR: expected build/site/book/ not found"
  exit 1
fi

log "Rendering Ruby mini-book..."
( cd "${REPO_DIR}" && npx antora antora-ruby-playbook.yml )

if [ ! -d "${REPO_DIR}/build/ruby-site/book" ]; then
  log "ERROR: expected build/ruby-site/book/ not found"
  exit 1
fi

publish_release "${RAILS_APP_DIR}" "${RAILS_RELEASE_DIR}" "${REPO_DIR}/build/site"
mkdir -p "${RUBY_APP_DIR}/shared"
publish_release "${RUBY_APP_DIR}" "${RUBY_RELEASE_DIR}" "${REPO_DIR}/build/ruby-site"

log "Deploy complete: ${TIMESTAMP}"
log "  Rails:  ${RAILS_APP_DIR}/current -> $(readlink -f "${RAILS_APP_DIR}/current")"
log "  Ruby:   ${RUBY_APP_DIR}/current -> $(readlink -f "${RUBY_APP_DIR}/current")"
