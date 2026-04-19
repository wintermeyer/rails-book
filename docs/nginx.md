# Nginx setup on bremen2 for `/rails/book/`

One-time setup. The Rails book deploy just refreshes
`/var/www/learn-ruby-on-rails-book/current/`; nginx has to be told to
serve that path under `/rails/book/` on the `wintermeyer-consulting.de`
vhost.

## 1. Filesystem layout

Run as the deploy user that owns the site (the `eliph` user is the
simplest — it already owns `/var/www/elixir-phoenix-ash/` and is the
one the GitHub Actions runner executes as):

```sh
sudo mkdir -p /var/www/learn-ruby-on-rails-book/{releases,shared}
sudo chown -R eliph:eliph /var/www/learn-ruby-on-rails-book
```

## 2. Nginx location block

Add inside the existing `server { server_name wintermeyer-consulting.de; … }`
on bremen2 (beside the Elixir book's `/phoenix/` blocks). The trailing
slash on `alias` is required — without it, URLs like `/rails/book/foo.html`
resolve to the wrong filesystem path.

```nginx
# Rails book — static Asciidoctor output rebuilt on every push to main.
location /rails/book/ {
    alias /var/www/learn-ruby-on-rails-book/current/;
    try_files $uri $uri/ /learn-ruby-on-rails.html;
    add_header Cache-Control "public, max-age=300";
}

location = /rails/book {
    return 301 /rails/book/;
}
```

Keep these blocks *before* any wincon `location /` proxy block so the
static files win over the Phoenix upstream. `/rails` (no trailing
slash, no `/book`) stays proxied to wincon — that route is the Rails
landing page served by `WinconWeb.PageController`.

## 3. Reload

```sh
sudo nginx -t && sudo systemctl reload nginx
```

## 4. Smoke test

```sh
curl -I https://wintermeyer-consulting.de/rails/book/
curl -I https://wintermeyer-consulting.de/rails/book/activerecord.html
```

Both should return `HTTP/2 200` once the first deploy has populated
`current/`.

## Notes

- The first deploy will publish into `releases/<timestamp>/` and create
  `current` → that dir. Until the symlink exists, the location block
  will 404.
- If the eliph runner fails the deploy, roll back by pointing the
  symlink at a previous release:

  ```sh
  ls /var/www/learn-ruby-on-rails-book/releases/
  ln -sfn /var/www/learn-ruby-on-rails-book/releases/<older-ts> \
         /var/www/learn-ruby-on-rails-book/current
  ```
