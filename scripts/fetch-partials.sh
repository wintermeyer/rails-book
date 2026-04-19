#!/usr/bin/env bash
# Fetch the canonical nav + footer partials from wincon and write
# them into one or more ui-supplemental/ directories so Antora
# overrides the shared UI bundle's header-content.hbs /
# footer-content.hbs with book-specific content.
#
# This repo publishes TWO Antora sites:
#   - main Rails book    -> ./ui-supplemental/               (rails)
#   - Ruby mini-book     -> ./ruby-book/ui-supplemental/     (ruby)
#
# Each site gets the same fetched footer but its own header with
# a different data-book-current stamp, which drives which stack
# link gets highlighted in the top nav.
#
# Source of truth: https://wintermeyer-consulting.de/partials/
# (served from wincon/priv/static/partials/).
#
# Falls back to the GitHub raw URL when production is unreachable.
# On total failure the supplemental files are left as-is; Antora
# then falls back to the UI bundle's defaults (empty stamp, no
# highlight) and the deploy still succeeds.

set -u

PROD_BASE="https://wintermeyer-consulting.de/partials"
GH_BASE="https://raw.githubusercontent.com/wintermeyer/wincon/main/priv/static/partials"

cd "$(dirname "$0")/.."

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

stamp_book_for() {
  local partials_dir="$1"
  local book_current="$2"

  mkdir -p "${partials_dir}"

  try_fetch footer.html "${partials_dir}/footer-content.hbs" || true

  if try_fetch book-nav.html "${partials_dir}/header-content.hbs"; then
    local tmp="${partials_dir}/header-content.hbs.tmp"
    sed -e "s/data-book-current=\"\"/data-book-current=\"${book_current}\"/" \
      "${partials_dir}/header-content.hbs" > "${tmp}"
    mv "${tmp}" "${partials_dir}/header-content.hbs"
  fi
}

stamp_book_for "ui-supplemental/partials" "rails"
stamp_book_for "ruby-book/ui-supplemental/partials" "ruby"
