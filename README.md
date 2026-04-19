# Learn Ruby on Rails

Source for the book _Learn Ruby on Rails_ by Stefan Wintermeyer.

The book targets **Ruby 4.0** and **Ruby on Rails 8.1**. Examples
have been re-run against these versions and screenshots are taken
from fresh Rails 8 scaffolds. Chapters added during the 5.2 → 8.1
refresh include Hotwire (Turbo + Stimulus), the built-in
authentication generator, and the Solid trifecta (Solid Queue /
Solid Cache / Solid Cable).

## Design

The HTML output is styled to match
[wintermeyer-consulting.de](https://www.wintermeyer-consulting.de)
(source repo [`wintermeyer/wincon`](https://github.com/wintermeyer/wincon)).
System fonts only (Georgia for headings, system sans for body,
ui-monospace for labels), dark mode via `prefers-color-scheme`, lime
accent on a neutral palette.

The **nav bar and footer are canonical in wincon**
(`priv/static/partials/{book-nav,footer}.html`) and pulled in by
`scripts/fetch-partials.sh` at deploy time. This keeps the three sites
visually `aus einem Guss`:

- <https://wintermeyer-consulting.de> (wincon, Phoenix)
- <https://wintermeyer-consulting.de/phoenix/book/> (Antora)
- <https://wintermeyer-consulting.de/rails/book/> (this book)

Book chapter content styling lives in `assets/book.css` (handwritten).
The shared chrome uses Tailwind utility classes; the utility rules are
emitted to `chrome.css` by `npx tailwindcss` during `rake html`.

Multi-page HTML is produced with `asciidoctor-multipage` (one HTML
file per chapter, plus a landing page with the full table of contents).
`scripts/wrap_pages.rb` post-processes each chapter to inject the
nav bar, footer, and `<link rel="stylesheet" href="chrome.css">`.

## Requirements

- Ruby 4.0 (pinned in `.tool-versions`, manage with
  [mise](https://mise.jdx.dev))
- Node 20 (for the Tailwind CLI; also pinned in `.tool-versions`)
- Bundler (ships with Ruby)

## Install

```sh
bundle install
npm install
```

## Build

```sh
bundle exec rake html   # HTML output in output/
bundle exec rake pdf    # PDF output in output/
bundle exec rake build  # both
bundle exec rake clean  # remove output/ and .scratch/
```

Running `rake html` automatically:

1. Compiles `chrome.css` via Tailwind (from `assets/chrome.css`).
2. Renders the book with `asciidoctor-multipage`.
3. Wraps every chapter page with the wincon nav and footer.

To refresh the nav and footer from the live wincon server before the
build (optional — the committed copies under `assets/` work offline):

```sh
bundle exec rake fetch_partials
bundle exec rake html
```

Master file: `learn-ruby-on-rails.adoc`.

## Deployment

Pushing to `main` triggers `.github/workflows/deploy.yml`, which runs
on the self-hosted runner (label `eliph`) on bremen2. The runner
checks the repo out and runs `scripts/deploy.sh`, which:

1. Activates mise (Ruby + Node from `.tool-versions`).
2. Runs `scripts/fetch-partials.sh` to pull the canonical nav + footer
   from wincon (with fallbacks to the GitHub raw URL and the committed
   copies on failure).
3. Installs Ruby gems and npm packages.
4. Runs `rake html`.
5. Copies `output/` to `/var/www/learn-ruby-on-rails-book/releases/<timestamp>/`
   and atomically swaps the `current` symlink.
6. Prunes old releases (keeps last 5).

Nginx on bremen2 serves `/rails/book/` from
`/var/www/learn-ruby-on-rails-book/current/` (one-time setup — see
[`docs/nginx.md`](docs/nginx.md)).

Pull requests run the build-only workflow on a GitHub-hosted Ubuntu
runner (`.github/workflows/build.yml`) to catch regressions before
merge; artifacts are uploaded for inspection but nothing is deployed.

## License

See individual files for attribution.
