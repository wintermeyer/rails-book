#!/usr/bin/env bash
# Fetch the canonical nav + footer partials from wincon and overwrite
# ui-bundle/src/partials/{header,footer}-content.hbs before the UI
# bundle is built.
#
# Source of truth: https://wintermeyer-consulting.de/partials/
# (served from wincon/priv/static/partials/).
#
# Falls back to the GitHub raw URL when production is unreachable.
# Keeps the committed .hbs files as-is on total failure so deploys
# do not break on a transient network glitch.

set -u

PROD_BASE="https://wintermeyer-consulting.de/partials"
GH_BASE="https://raw.githubusercontent.com/wintermeyer/wincon/main/priv/static/partials"
BOOK_CURRENT="rails"

cd "$(dirname "$0")/.."

PARTIALS_DIR="ui-bundle/src/partials"

try_fetch() {
  local source_name="$1"
  local dest="$2"

  if curl -fsSL --max-time 10 -o "${dest}.tmp" "${PROD_BASE}/${source_name}"; then
    mv "${dest}.tmp" "${dest}"
    echo "fetched ${source_name} -> ${dest} (production)"
    return 0
  fi

  if curl -fsSL --max-time 10 -o "${dest}.tmp" "${GH_BASE}/${source_name}"; then
    mv "${dest}.tmp" "${dest}"
    echo "fetched ${source_name} -> ${dest} (GitHub raw)"
    return 0
  fi

  rm -f "${dest}.tmp"
  echo "WARN: could not fetch ${source_name}; keeping ${dest}"
  return 1
}

try_fetch footer.html "${PARTIALS_DIR}/footer-content.hbs" || true

if try_fetch book-nav.html "${PARTIALS_DIR}/header-content.hbs"; then
  # Highlight the Rails link in the shared book nav.
  tmp="${PARTIALS_DIR}/header-content.hbs.tmp"
  sed -e "s/data-book-current=\"\"/data-book-current=\"${BOOK_CURRENT}\"/" \
    "${PARTIALS_DIR}/header-content.hbs" > "$tmp"
  mv "$tmp" "${PARTIALS_DIR}/header-content.hbs"
fi
