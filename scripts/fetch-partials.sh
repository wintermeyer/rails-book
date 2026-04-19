#!/usr/bin/env bash
# Fetch the canonical nav + footer partials from wincon and write
# them into ./ui-supplemental/partials/ so Antora overrides the
# header-content.hbs / footer-content.hbs shipped with the shared
# UI bundle (wintermeyer/wincon-antora-ui).
#
# Source of truth: https://wintermeyer-consulting.de/partials/
# (served from wincon/priv/static/partials/).
#
# Falls back to the GitHub raw URL when production is unreachable.
# On total failure the supplemental files are left as-is; Antora
# falls back to the UI bundle's defaults and the deploy still works.

set -u

PROD_BASE="https://wintermeyer-consulting.de/partials"
GH_BASE="https://raw.githubusercontent.com/wintermeyer/wincon/main/priv/static/partials"
BOOK_CURRENT="rails"

cd "$(dirname "$0")/.."

PARTIALS_DIR="ui-supplemental/partials"
mkdir -p "${PARTIALS_DIR}"

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
  tmp="${PARTIALS_DIR}/header-content.hbs.tmp"
  sed -e "s/data-book-current=\"\"/data-book-current=\"${BOOK_CURRENT}\"/" \
    "${PARTIALS_DIR}/header-content.hbs" > "$tmp"
  mv "$tmp" "${PARTIALS_DIR}/header-content.hbs"
fi
