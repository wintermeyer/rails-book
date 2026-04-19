# Learn Ruby on Rails

Source for the book _Learn Ruby on Rails_ by Stefan Wintermeyer,
targeting **Ruby 4.0** and **Ruby on Rails 8.1**.

## Design

The book is built with [Antora](https://antora.org). The visual
chrome (Tailwind v4 theme, sidebars, TOC, pagination, mobile nav)
comes from the shared UI bundle at
[`wintermeyer/wincon-antora-ui`](https://github.com/wintermeyer/wincon-antora-ui),
which is also used by the Phoenix book at `/phoenix/book/` — so both
books feel like one publication.

The wincon top nav and site-wide footer are pulled at build time
from
[`wincon/priv/static/partials/`](https://github.com/wintermeyer/wincon/tree/main/priv/static/partials)
by `scripts/fetch-partials.sh`, which stamps
`data-book-current="rails"` into the nav so the Rails link is
highlighted. The fetched HTML lands in `ui-supplemental/partials/`
and Antora's `ui.supplemental_files` overlay substitutes it for the
UI bundle's default `header-content.hbs` / `footer-content.hbs`.

Dark mode follows `prefers-color-scheme`. System fonts only (Georgia
for headings, system sans for body, ui-monospace for code).

## Source layout

```
antora.yml                      # component descriptor
antora-playbook.yml             # production site playbook (pulls remote content)
antora-local-playbook.yml       # local dev: this working copy as source
modules/
  ROOT/
    nav.adoc                    # sidebar structure
    pages/*.adoc                # one chapter per file
    images/screenshots/         # referenced via image::screenshots/...
scripts/
  deploy.sh                     # self-hosted runner build + atomic swap
  fetch-partials.sh             # pull wincon nav + footer at build time
docs/nginx.md                   # one-time bremen2 nginx setup
```

`ui-supplemental/` is gitignored — it's generated at every deploy.

## Requirements

- Node 20+

## Build locally

```sh
npm install
npx antora --fetch antora-local-playbook.yml   # renders into build/site/
```

`--fetch` pulls the UI bundle from
<https://github.com/wintermeyer/wincon-antora-ui/releases/download/latest/ui-bundle.zip>.
Open `build/site/book/index.html` in a browser to preview.

To refresh the nav + footer from the live wincon server before the
build (optional — without this the UI bundle's default empty
`data-book-current` is used and nothing is highlighted):

```sh
./scripts/fetch-partials.sh
```

## Deployment

Pushing to `main` triggers `.github/workflows/deploy.yml`, which
runs on the dedicated self-hosted runner (label `books`) on bremen2.
The runner checks the repo out and executes `scripts/deploy.sh`:

1. Activate mise (Node pinned via `.tool-versions` on the runner's
   profile; no repo-local pin anymore).
2. `scripts/fetch-partials.sh` — pulls canonical nav + footer from
   wincon into `ui-supplemental/`.
3. `npm ci` installs Antora.
4. `npx antora --fetch antora-playbook.yml` renders into
   `build/site/`; the UI bundle is pulled from wincon-antora-ui.
5. Copy `build/site/` → `/var/www/learn-ruby-on-rails-book/releases/<ts>/`.
6. Atomically swap the `current` symlink.
7. Prune old releases (keep last 5).

Nginx on bremen2 serves `/rails/book/` from
`/var/www/learn-ruby-on-rails-book/current/book/` and
`/rails/antora-assets/` from `…/current/antora-assets/` (see
[`docs/nginx.md`](docs/nginx.md)).

## License

See individual files for attribution.
