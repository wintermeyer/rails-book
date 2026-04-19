# Learn Ruby on Rails

Source for the book _Learn Ruby on Rails_ by Stefan Wintermeyer,
targeting **Ruby 4.0** and **Ruby on Rails 8.1**.

## Design

The book is built with [Antora](https://antora.org) and shares its
UI bundle with the Elixir/Phoenix book
([`wintermeyer/elixir-phoenix-ash`](https://github.com/wintermeyer/elixir-phoenix-ash)).
Both books render with the same chrome — left sidebar nav, right
"On this page" TOC, prev/next pagination, mobile nav toggle — so
they feel like one publication.

The wincon top nav and site-wide footer are pulled at build time
from the canonical source in
[`wincon/priv/static/partials/`](https://github.com/wintermeyer/wincon/tree/main/priv/static/partials)
(see `scripts/fetch-partials.sh`, which stamps
`data-book-current="rails"` into the nav so the Rails link is
highlighted).

Dark mode follows `prefers-color-scheme`. System fonts only (Georgia
for headings, system sans for body, ui-monospace for code).

## Source layout

```
antora.yml                      # component descriptor
antora-playbook.yml             # production site playbook
antora-local-playbook.yml       # local dev: source is this working copy
modules/
  ROOT/
    nav.adoc                    # sidebar structure
    pages/*.adoc                # one chapter per file
    images/screenshots/         # referenced via image::screenshots/...
ui-bundle/                      # vendored copy of the Antora UI bundle
                                # (canonical source in elixir-phoenix-ash)
scripts/
  deploy.sh                     # self-hosted runner build + atomic swap
  fetch-partials.sh             # pull wincon nav + footer at build time
docs/nginx.md                   # one-time bremen2 nginx setup
```

## Requirements

- Node 20+ (Antora 3, Tailwind v4)

## Build locally

```sh
npm install                          # installs Antora
cd ui-bundle && npm install && npm run build && cd ..
npx antora antora-local-playbook.yml # renders into build/site/
```

Open `build/site/book/index.html` in a browser to preview.

To refresh the nav + footer from the live wincon server before the
build (optional — the vendored copies work offline):

```sh
./scripts/fetch-partials.sh
```

## Deployment

Pushing to `main` triggers `.github/workflows/deploy.yml`, which runs
on a dedicated self-hosted runner (label `eliph`) on bremen2. The
runner checks the repo out and executes `scripts/deploy.sh`:

1. Activate mise (Node pinned in `ui-bundle/package.json`).
2. `scripts/fetch-partials.sh` — pulls canonical nav + footer from
   wincon.
3. Build the UI bundle (`ui-bundle.zip`).
4. Install Antora, render with `antora-playbook.yml`.
5. Copy `build/site/` → `/var/www/learn-ruby-on-rails-book/releases/<ts>/`.
6. Atomically swap the `current` symlink.
7. Prune old releases (keep last 5).

Nginx on bremen2 serves `/rails/book/` from
`/var/www/learn-ruby-on-rails-book/current/book/` (see
[`docs/nginx.md`](docs/nginx.md)).

## License

See individual files for attribution.
