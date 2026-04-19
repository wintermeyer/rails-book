#!/usr/bin/env bash
# Fetch the canonical nav + footer partials from wincon into
# .scratch/partials/. The Rakefile prefers these over the committed
# fallbacks in assets/ when they exist.
#
# Source of truth: https://wintermeyer-consulting.de/partials/
# (served from wincon/priv/static/partials/).
#
# Falls back to the GitHub raw URL when the production site is
# unreachable — useful during CI bootstrap or when wincon is down.
#
# On fetch failure, the script does NOT exit with an error: the
# Rakefile will transparently use the committed fallbacks. Net
# problems should never break a deploy.

set -u

PROD_BASE="https://wintermeyer-consulting.de/partials"
GH_BASE="https://raw.githubusercontent.com/wintermeyer/wincon/main/priv/static/partials"
BOOK_CURRENT="rails"

cd "$(dirname "$0")/.."

mkdir -p .scratch/partials

fetch_one() {
  local name="$1"
  local dest=".scratch/partials/${name}"

  if curl -fsSL --max-time 10 -o "${dest}.tmp" "${PROD_BASE}/${name}"; then
    mv "${dest}.tmp" "${dest}"
    echo "fetched ${name} from production"
    return 0
  fi

  if curl -fsSL --max-time 10 -o "${dest}.tmp" "${GH_BASE}/${name}"; then
    mv "${dest}.tmp" "${dest}"
    echo "fetched ${name} from GitHub raw"
    return 0
  fi

  rm -f "${dest}.tmp"
  echo "WARN: could not fetch ${name}; falling back to assets/${name}"
  return 1
}

fetch_one footer.html || true

if fetch_one book-nav.html; then
  # Stamp "rails" into data-book-current so the Rails nav link is
  # highlighted by the CSS rule in assets/chrome.css.
  tmp=".scratch/partials/book-nav.html.tmp"
  sed -e "s/data-book-current=\"\"/data-book-current=\"${BOOK_CURRENT}\"/" \
    .scratch/partials/book-nav.html > "$tmp"
  mv "$tmp" .scratch/partials/nav.html
  rm -f .scratch/partials/book-nav.html
fi
